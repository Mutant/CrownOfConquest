package RPG::NewDay::Action::Kingdom;

use Moose;

extends 'RPG::NewDay::Base';

use List::Util qw(shuffle reduce);
use RPG::Template;
use Try::Tiny;
use DateTime;

use RPG::Schema::Quest_Type;

sub depends { qw/RPG::NewDay::Action::Mayor/ }

sub run {
    my $self = shift;
    my $c    = $self->context;

    my $schema = $c->schema;

    $self->decrement_banished_parties;

    my @kingdoms = $schema->resultset('Kingdom')->search(
        {
            active => 1,
        }
    );

    foreach my $kingdom (@kingdoms) {
        my $king = $kingdom->king;

        next unless $king;

        $self->check_for_coop( $kingdom, $king ) if !$king->is_npc;

        $self->cancel_quests_awaiting_acceptance($kingdom);

        $self->adjust_party_loyalty($kingdom);

        if ( $king->is_npc ) {
            $self->execute_npc_kingdom_actions( $kingdom, $king );
        }
    }

    $self->force_co_op_change_of_allegiance;
}

sub quest_type_map {
    my $self = shift;

    unless ( $self->{quest_type_map} ) {
        my @quest_types = $self->context->schema->resultset('Quest_Type')->search(
            {
                owner_type => 'kingdom',
            },
        );
        $self->{quest_type_map} = { map { $_->id => $_->quest_type } @quest_types };
    }

    return $self->{quest_type_map};
}

sub execute_npc_kingdom_actions {
    my $self    = shift;
    my $kingdom = shift;
    my $king    = shift;

    $self->context->logger->info( "Processing NPC Actions for Kingdom " . $kingdom->name . " id: " . $kingdom->id );

    if ( !$kingdom->capital ) {
        $self->select_capital($kingdom);
    }

    my @parties = $kingdom->search_related(
        'parties',
        {
            defunct => undef,
        },
    );

    $self->context->logger->debug( "Kingdom has " . scalar @parties . " parties" );

    $self->banish_parties( $kingdom, @parties );

    # Some parties might have been banned, so remove them
    @parties = grep { $_->kingdom_id == $kingdom->id } @parties;

    $self->generate_kingdom_quests( $kingdom, @parties );

    $self->resolve_claims($kingdom);
}

sub generate_kingdom_quests {
    my $self    = shift;
    my $kingdom = shift;
    my @parties = @_;

    return unless @parties;

    my $c = $self->context;

    my @quest_count = $c->schema->resultset('Quest')->search(
        {
            kingdom_id => $kingdom->id,
            status => [ 'Not Started', 'In Progress' ],
        },
        {
            'select' => [ 'quest_type_id', { 'count' => '*' } ],
            'as' => [ 'quest_type_id', 'count' ],
            'group_by' => 'quest_type_id',
        }
    );

    my %counts;
    foreach my $count_rec (@quest_count) {
        $counts{ $self->quest_type_map->{ $count_rec->quest_type_id } } = $count_rec->get_column('count') // 0;
    }

    my $quests_allowed       = $kingdom->quests_allowed;
    my $total_current_quests = $kingdom->search_related(
        'quests',
        {
            status => [ 'Not Started', 'In Progress' ],
        }
    )->count;

    $c->logger->debug("Has $total_current_quests quests, allowed $quests_allowed");

    my $quests_to_create = $quests_allowed - $total_current_quests;

    for my $quest_type ( values %{ $self->quest_type_map } ) {

        # TODO: currently create 3 of each quest type. Should change this
        my $base_number = 3;
        my $number_to_create = $base_number - ( $counts{$quest_type} // 0 );

        $number_to_create = $quests_to_create if $quests_to_create < $number_to_create;

        next if $number_to_create <= 0;

        my $min_level = RPG::Schema::Quest_Type->min_level($quest_type);

        $self->_create_quests_of_type( $quest_type, $number_to_create, $min_level, $kingdom, \@parties );
    }
}

sub _create_quests_of_type {
    my $self             = shift;
    my $quest_type       = shift;
    my $number_to_create = shift;
    my $minimum_level    = shift;
    my $kingdom          = shift;
    my $parties          = shift;

    my $c = $self->context;

    my $quest_type_rec = $c->schema->resultset('Quest_Type')->find(
        {
            quest_type => $quest_type,
        },
    );

    confess "No such quest type: $quest_type\n" unless $quest_type_rec;

    $self->context->logger->debug( "Attempting to create $number_to_create quests of type: " . $quest_type );

    for ( 1 .. $number_to_create ) {
        my @eligible = $self->_find_eligible_parties( $minimum_level, $quest_type, @$parties );

        next unless @eligible;

        @eligible = shuffle @eligible;

        my $party = shift @eligible;

        my $quest = try {
            $c->schema->resultset('Quest')->create(
                {
                    kingdom_id    => $kingdom->id,
                    party_id      => $party->id,
                    quest_type_id => $quest_type_rec->id,
                    day_offered   => $c->current_day->id,
                }
            );
        }
        catch {
            if ( ref $_ && $_->isa('RPG::Exception') ) {
                if ( $_->type eq 'quest_creation_error' ) {
                    $c->logger->debug( "Couldn't create quest: " . $_->message );
                    next;
                }
                die $_->message;
            }

            die $_;
        };

        if ( $quest->gold_value > $kingdom->gold ) {

            # Not enough gold to create this quest, skip it
            $self->context->logger->debug( "No enough gold to fund this quest, deleting (have: " . $kingdom->gold . ", need: " . $quest->gold_value . ')' );
            $quest->delete;
            next;
        }

        $quest->create_party_offer_message;

        $kingdom->decrease_gold( $quest->gold_value );

    }
}

# Given a list of parties, return parties above a certain level, and without a particular quest type
sub _find_eligible_parties {
    my $self       = shift;
    my $min_level  = shift;
    my $quest_type = shift;
    my @parties    = @_;

    my @eligible = grep {
        $_->level >= $min_level &&
          $_->active_quests_of_type($quest_type)->count < 1
    } @parties;

    return @eligible;
}

# Cancel any quests that have been awaiting acceptance by the party for too long
sub cancel_quests_awaiting_acceptance {
    my $self    = shift;
    my $kingdom = shift;

    my $expired_day_number = $self->context->current_day->day_number - $self->context->config->{kingdom_quest_offer_time_limit};
    my $day_rec = $self->context->schema->resultset('Day')->find(
        {
            day_number => $expired_day_number,
        }
    );

    return unless $day_rec;

    my @quests_to_cancel = $self->context->schema->resultset('Quest')->search(
        {
            kingdom_id                   => $kingdom->id,
            status                       => 'Not Started',
            'day_offered_rec.day_number' => { '<=', $day_rec->day_number },
        },
        {
            join => 'day_offered_rec',
        },
    );

    foreach my $quest (@quests_to_cancel) {
        my $message = RPG::Template->process(
            $self->context->config,
            'quest/kingdom/offer_expired.html',
            {
                quest => $quest,
            }
        );

        my $kingdom_message = RPG::Template->process(
            RPG::Schema->config,
            'quest/kingdom/terminated.html',
            {
                quest  => $quest,
                reason => 'the party took too long to accept it',
            },
        );

        $quest->terminate(
            party_message   => $message,
            kingdom_message => $kingdom_message,
        );
        $quest->update;

    }
}

# Adjust loyalty of parties
sub adjust_party_loyalty {
    my $self    = shift;
    my $kingdom = shift;

    my $c = $self->context;

    my @parties = $kingdom->parties;
    foreach my $party (@parties) {

        # Adjust loyalty based on number of towns owned by party that are loyal to kingdom
        my $loyal_town_count = $c->schema->resultset('Town')->search(
            {
                'mayor.party_id'      => $party->id,
                'location.kingdom_id' => $kingdom->id,
            },
            {
                join => [ 'mayor', 'location' ],
            }
        )->count;

        my $disloyal_town_count = $c->schema->resultset('Town')->search(
            {
                'mayor.party_id' => $party->id,
                'location.kingdom_id' => [ { '!=', $kingdom->id }, undef ],
            },
            {
                join => [ 'mayor', 'location' ],
            }
        )->count;

        my $party_kingdom = $c->schema->resultset('Party_Kingdom')->find_or_create(
            {
                'party_id'   => $party->id,
                'kingdom_id' => $kingdom->id,
            }
        );
        $party_kingdom->adjust_loyalty( $loyal_town_count - $disloyal_town_count );
        $party_kingdom->update;
    }
}

sub banish_parties {
    my $self    = shift;
    my $kingdom = shift;
    my @parties = @_;

    # Only banish parties if there are enough
    return unless $kingdom->parties->count >= $self->context->config->{npc_kingdom_min_parties};

    # Find parties with low loyalty ratings
    my @disloyal_parties = grep { $_->loyalty_for_kingdom( $kingdom->id ) <= -60 } @parties;
    return unless @disloyal_parties;

    my $chance_to_ban = Games::Dice::Advanced->roll('1d100');

    if ( $chance_to_ban <= 35 ) {
        my $party_to_ban    = ( shuffle @disloyal_parties )[0];
        my $duration_to_ban = ( shuffle qw(10 15 20 25 30) )[0];
        $party_to_ban->banish_from_kingdom( $kingdom, $duration_to_ban );
    }
}

sub decrement_banished_parties {
    my $self = shift;

    my $c = $self->context;

    my @party_kingdom = $c->schema->resultset('Party_Kingdom')->search(
        {
            banished_for => { '>=', 0 },
        }
    );

    foreach my $party_kingdom (@party_kingdom) {
        $party_kingdom->decrement_banished_for;
        $party_kingdom->update;
    }
}

sub check_for_coop {
    my $self    = shift;
    my $kingdom = shift;
    my $king    = shift;

    return if $king->is_npc;

    my $c = $self->context;

    my $kings_party = $king->party;

    my @parties = $kingdom->parties;

    foreach my $party (@parties) {
        next if $party->id == $kings_party->id;

        next if $party->warned_for_kingdom_co_op;

        if ( $party->is_suspected_of_coop_with($kings_party) ) {

            $party->warned_for_kingdom_co_op( DateTime->now() );
            $party->last_allegiance_change(undef);
            $party->update;

            $party->add_to_messages(
                {
                    day_id      => $c->current_day->id,
                    alert_party => 1,
                    message => "You are loyal to a Kingdom where the King's party has IP addresses in common with your party. Please change allegiance within "
                      . $c->config->{kingdom_co_op_grace} . " days or your party will automatically become free citizens.",
                }
            );
        }
    }
}

sub force_co_op_change_of_allegiance {
    my $self = shift;

    my $c = $self->context;

    my $dt = DateTime->now->subtract( days => $c->config->{kingdom_co_op_grace} ) ;
    my $fdt = $c->schema->storage->datetime_parser->format_datetime($dt);

    my @parties_warned_for_co_op = $c->schema->resultset('Party')->search(
        {
            warned_for_kingdom_co_op => { '<=', $fdt },
        }
    );

    foreach my $party (@parties_warned_for_co_op) {
        my $kingdom = $party->kingdom;
        my $king;
        $king = $party->kingdom->king if $kingdom;

        if ( !$kingdom || $king->is_npc || !$party->is_suspected_of_coop_with( $king->party ) ) {

            # They're no longer doing co-op
            $party->warned_for_kingdom_co_op(undef);
            $party->update;
        }
        else {
            $party->warned_for_kingdom_co_op(undef);
            $party->change_allegiance(undef);
            $party->update;

            $party->add_to_messages(
                {
                    day_id      => $c->current_day->id,
                    alert_party => 1,
                    message => "Your allegiance was automatically changed to Free Citizen, as you were loyal to a kingdom where you had IP addresses in " .
                      "common with the King's party.",
                }
            );
        }
    }
}

sub select_capital {
    my $self    = shift;
    my $kingdom = shift;

    my $c = $self->context;

    my @towns = $kingdom->towns;

    return unless @towns;

    my $highest_prosp_town = reduce { $a->prosperity > $b->prosperity ? $a : $b } @towns;

    return unless $highest_prosp_town;

    if ( $kingdom->gold < $kingdom->move_capital_cost ) {

        # Give them enough gold to move it
        $kingdom->gold( $kingdom->move_capital_cost );
        $kingdom->update;
    }

    try {
        $kingdom->change_capital( $highest_prosp_town->id );
    }
    catch {
        if ( ref $_ && $_->isa('RPG::Exception') ) {
            if ( $_->type eq 'insufficient_gold' ) {

                # Not enough gold, just skip
                return;
            }
            die $_->message;
        }
        die $_;
    };
}

sub resolve_claims {
    my $self    = shift;
    my $kingdom = shift;

    my $c = $self->context;

    my $claim = $kingdom->current_claim;

    return unless $claim;

    return if $claim->days_left > 0;

    my %summary = $claim->response_summary;
    my $summary_string = $summary{support} . " supported, " . $summary{oppose} . " opposed";

    if ( $summary{support} > $summary{oppose} || ( $summary{support} == 0 && $summary{oppose} == 0 ) ) {

        # Claim successful
        $claim->outcome('successful');
        $claim->update;

        my $old_monarch = $kingdom->king;
        $old_monarch->status(undef);
        $old_monarch->status_context(undef);
        $old_monarch->update;

        my $new_monarch = $claim->claimant;
        $new_monarch->status_context( $kingdom->id );
        $new_monarch->status('king');
        $new_monarch->update;

        $new_monarch->party->add_to_messages(
            {
                day_id      => $c->current_day->id,
                alert_party => 1,
                message => "Our claim to the throne has been successful! ($summary_string) " . $new_monarch->character_name . " is now "
                  . ( $new_monarch->gender eq 'male' ? 'King' : 'Queen' ) . " of " . $kingdom->name,
            }
        );
    }
    else {
        # Claim failed
        $claim->outcome('failed');
        $claim->update;

        my $claimant = $claim->claimant;
        my $capital  = $kingdom->capital_city;
        if ( !$capital ) {
            my @towns = $kingdom->towns;
            if ( !@towns ) {

                # Kingdom has no towns, just pick a random one
                @towns = $c->schema->resultset('Towns')->search();
            }
            $capital = ( shuffle @towns )[0];
        }

        $claimant->status_context( $capital->id );
        $claimant->status('inn');
        $claimant->update;

        $claimant->party->add_to_messages(
            {
                day_id      => $c->current_day->id,
                alert_party => 1,
                message => "Our claim to the throne has failed! ($summary_string) " . $claimant->character_name . " is now in the inn of " .
                  $capital->town_name,
            }
        );
    }
}

1;
