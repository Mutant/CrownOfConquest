package RPG::C::Town;

use strict;
use warnings;
use base 'Catalyst::Controller';

use feature qw(switch);

use Math::Round qw(round);
use JSON;
use List::Util qw(shuffle);
use Carp;

sub main : Local {
    my ( $self, $c, $return_output ) = @_;

    my $town = $c->stash->{party_location}->town;

    my $parties_in_sector = $c->forward( '/party/parties_in_sector', [ $c->stash->{party_location}->id ] );

    $c->forward('/party/party_messages_check');

    my $party_town = $c->model('DBIC::Party_Town')->find_or_create(
        {
            party_id => $c->stash->{party}->id,
            town_id  => $town->id,
        },
    );

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'town/main.html',
                params   => {
                    town              => $town,
                    day_logs          => $c->stash->{day_logs},
                    party_messages    => $c->stash->{party_messages},
                    messages          => $c->stash->{messages},
                    parties_in_sector => $parties_in_sector,
                    prestige          => $party_town->prestige,
                    allowed_discount  => $town->discount_type && $party_town->prestige >= $town->discount_threshold ? 1 : 0,
                },
                return_output => $return_output || 0,
            }
        ]
    );
}

sub back_to_main : Local {
    my ( $self, $c ) = @_;

    my $panel = $c->forward( 'main', [1] );

    push @{ $c->stash->{refresh_panels} }, [ 'messages', $panel ];

    $c->forward('/panel/refresh');
}

sub shop_list : Local {
    my ( $self, $c ) = @_;

    my $panel = $c->forward(
        'RPG::V::TT',
        [
            {
                template      => 'town/shop_list.html',
                params        => { town => $c->stash->{party_location}->town, },
                return_output => 1,
            }
        ]
    );

    push @{ $c->stash->{refresh_panels} }, [ 'messages', $panel ];

    $c->forward('/panel/refresh');
}

sub healer : Local {
    my ( $self, $c ) = @_;

    my $town = $c->stash->{party_location}->town;

    my @characters = $c->stash->{party}->characters_in_party;

    my @dead_chars = grep { $_->is_dead } @characters;

    my $cost_to_heal = $c->forward( 'calculate_heal_cost', [$town] );

    my $panel = $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'town/healer.html',
                params   => {
                    party           => $c->stash->{party},
                    cost_to_heal    => $cost_to_heal,
                    dead_characters => \@dead_chars,
                    town            => $town,
                    messages        => $c->stash->{messages},
                },
                return_output => 1,
            }
        ]
    );

    push @{ $c->stash->{refresh_panels} }, [ 'messages', $panel ];

    $c->forward('/panel/refresh');
}

sub heal_party : Local {
    my ( $self, $c ) = @_;

    my $town = $c->stash->{party_location}->town;

    my @characters = $c->stash->{party}->characters_in_party;

    my $cost_to_heal = $c->forward( 'calculate_heal_cost', [$town] );

    my $amount_to_spend = defined $c->req->param('gold') ? $c->req->param('gold') : $cost_to_heal;
	
    my $percent_to_heal = 0;
    unless ($cost_to_heal == 0) {
    	$percent_to_heal = $amount_to_spend / $cost_to_heal * 100;
    }

    if ( $amount_to_spend <= $c->stash->{party}->gold ) {
        $c->stash->{party}->gold( $c->stash->{party}->gold - $amount_to_spend );
        $c->stash->{party}->update;

        foreach my $character (@characters) {
            next if $character->is_dead;

            my $amount_to_heal = int( $character->max_hit_points - $character->hit_points ) * ( $percent_to_heal / 100 );

            $character->hit_points( $character->hit_points + $amount_to_heal );
            $character->update;
        }

        if ( $percent_to_heal == 100 ) {
            $c->stash->{messages} = 'The party has been fully healed';
        }
        else {
            $c->stash->{messages} = "The party has been healed for $amount_to_spend gold";
        }
    }
    else {
        if ( $c->req->param('gold') ) {
            $c->stash->{error} = "You only have " . $c->stash->{party}->gold . " gold. You can't heal for more gold than you have!";
        }
        else {
            $c->stash->{error} = "You don't have enough gold for a full heal. Try a partial heal";
        }
    }

    push @{ $c->stash->{refresh_panels} }, ( 'party', 'party_status' );

    $c->forward('/town/healer');
}

sub resurrect : Local {
    my ( $self, $c ) = @_;

    my $town = $c->stash->{party_location}->town;

    my @characters = $c->stash->{party}->characters_in_party;

    my @dead_chars = grep { $_->is_dead } @characters;

    my ($char_to_res) = grep { $_->id eq $c->req->param('character_id') } @dead_chars;

    if ($char_to_res) {
        if ( $char_to_res->resurrect_cost > $c->stash->{party}->gold ) {
            $c->stash->{error} = "You don't have enough gold to resurrect " . $char_to_res->character_name;
        }
        else {
            $c->stash->{party}->gold( $c->stash->{party}->gold - $char_to_res->resurrect_cost );
            $c->stash->{party}->update;

            $char_to_res->hit_points( round $char_to_res->max_hit_points * 0.1 );
            $char_to_res->hit_points(1) if $char_to_res->hit_points < 1;
            my $xp_to_lose = int( $char_to_res->xp * RPG->config->{ressurection_percent_xp_to_lose} / 100 );
            $char_to_res->xp( $char_to_res->xp - $xp_to_lose );
            $char_to_res->update;

            my $message =
                  $char_to_res->character_name
                . " was ressurected by the healer in the town of "
                . $town->town_name
                . " and has risen from the dead. "
                . $char_to_res->pronoun('subjective')
                . " lost $xp_to_lose xp.";

            $c->model('DBIC::Character_History')->create(
                {
                    character_id => $char_to_res->id,
                    day_id       => $c->stash->{today}->id,
                    event        => $message,
                },
            );

            $c->stash->{messages} = $message;
        }
    }

    push @{ $c->stash->{refresh_panels} }, ( 'party', 'party_status' );

    $c->forward('/town/healer');
}

sub calculate_heal_cost : Private {
    my ( $self, $c, $town ) = @_;

    my $per_hp_heal_cost = round( $c->config->{min_healer_cost} + ( 100 - $town->prosperity ) / 100 * $c->config->{max_healer_cost} );

    my $cost_to_heal = 0;

    foreach my $character ( $c->stash->{party}->characters_in_party ) {
        next if $character->is_dead;

        $cost_to_heal += $per_hp_heal_cost * ( $character->max_hit_points - $character->hit_points );
    }

    if ( $town->discount_type eq 'healer' && $c->stash->{party}->prestige_for_town($town) >= $town->discount_threshold ) {
        $cost_to_heal = round( $cost_to_heal * ( 100 - $town->discount_value ) / 100 );
    }

    return $cost_to_heal;
}

sub news : Local {
    my ( $self, $c ) = @_;

    my $current_day = $c->stash->{today}->day_number;
    my $town        = $c->stash->{party_location}->town;

    my @logs = $c->model('DBIC::Town_History')->search(
        {
            town_id          => $town->id,
            'day.day_number' => { '<=', $current_day, '>=', $current_day - $c->config->{news_day_range} },
        },
        {
            prefetch => 'day',
            order_by => 'day_number desc, date_recorded',
        }
    );

    my $panel = $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'town/news.html',
                params   => {
                    town => $town,
                    logs => \@logs,
                },
                return_output => 1,
            }
        ]
    );

    push @{ $c->stash->{refresh_panels} }, [ 'messages', $panel ];

    $c->forward('/panel/refresh');
}

sub quests : Local {
    my ( $self, $c ) = @_;

    # See if party has a quest for this town
    my $party_quest = $c->model('DBIC::Quest')->find(
        {
            town_id  => $c->stash->{party_location}->town->id,
            party_id => $c->stash->{party}->id,
            status   => 'In Progress',
        },
    );

    # If the have a quest to complete, send them there now
    if ( $party_quest && $party_quest->ready_to_complete ) {
        $c->detach( '/quest/complete_quest', [$party_quest] );
    }

    # Check for quest actions which can be triggered by a visit to the town hall
    my $quest_messages = $c->forward( '/quest/check_action', ['townhall_visit'] );

	my $allowed_more_quests = $c->stash->{party}->allowed_more_quests;

    my @quests;

    # If they don't have a quest, load in available quests
    if ( !$party_quest && $allowed_more_quests ) {
        @quests = shuffle $c->model('DBIC::Quest')->search(
            {
                town_id        => $c->stash->{party_location}->town->id,
                party_id       => undef,
            },
            { prefetch => 'type', },
        );
    }

    my $panel = $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'town/quests.html',
                params   => {
                    town                => $c->stash->{party_location}->town,
                    quests              => \@quests,
                    party_quest         => $party_quest,
                    allowed_more_quests => $allowed_more_quests,
                    quest_messages      => $quest_messages,
                },
                return_output => 1,
            }
        ]
    );

    push @{ $c->stash->{refresh_panels} }, [ 'messages', $panel ];

    $c->forward('/panel/refresh');
}

sub cemetry : Local {
    my ( $self, $c ) = @_;

    my @graves = $c->model('DBIC::Grave')->search( { land_id => $c->stash->{party_location}->id, }, );

    my $panel = $c->forward(
        'RPG::V::TT',
        [
            {
                template      => 'town/cemetery.html',
                params        => { graves => \@graves, },
                return_output => 1,
            }
        ]
    );

    push @{ $c->stash->{refresh_panels} }, [ 'messages', $panel ];

    $c->forward('/panel/refresh');
}

sub enter : Local {
    my ( $self, $c ) = @_;

    my $town = $c->model('DBIC::Town')->find( { land_id => $c->req->param('land_id') } );
    
    unless ($c->forward('/map/can_move_to_sector', [$town->location])) {
    	# Can't move to this town for whatever reason
    	$c->detach( '/panel/refresh', [  'messages', 'party_status' ] );	
    }

    my $party_town = $c->model('Party_Town')->find_or_create(
        {
            party_id => $c->stash->{party}->id,
            town_id  => $town->id,
        },
    );

    # Check if they have really low prestige, and need to be refused.
    my $prestige_threshold = -90 + round( $town->prosperity / 25 );
    if ( $party_town->prestige <= $prestige_threshold ) {
        $c->stash->{panel_messages} =
            [ "You've been refused entry to " . $town->town_name . ". You'll need to wait until your prestige improves before coming back" ];
        $c->detach( '/panel/refresh', ['messages'] );
    }

    # Pay tax, if necessary
    if ( !$party_town->tax_amount_paid_today ) {
        croak "Payment method not specified" unless $c->req->param('payment_method');

        my $cost = $town->tax_cost( $c->stash->{party} );

        if ( $c->req->param('payment_method') eq 'gold' ) {
            if ( $cost->{gold} > $c->stash->{party}->gold ) {
                $c->stash->{panel_messages} = ["You don't have enough gold to pay the tax"];
                $c->detach( '/panel/refresh', ['messages'] );
            }

            $c->stash->{party}->gold( $c->stash->{party}->gold - $cost->{gold} );
        }
        else {
            if ( $cost->{turns} > $c->stash->{party}->turns ) {
                $c->stash->{panel_messages} = ["You don't have enough turns to pay the tax"];
                $c->detach( '/panel/refresh', ['messages'] );
            }

            $c->stash->{party}->turns( $c->stash->{party}->turns - $cost->{turns} );
        }

        $c->stash->{party}->update;

        # Record payment (Always recorded in gold)
        $party_town->tax_amount_paid_today( $cost->{gold} );

        $party_town->prestige( $party_town->prestige + 1 );
        $party_town->update;
    }

    $c->stash->{entered_town} = 1;

    $c->forward('/map/move_to');
}

sub raid : Local {
    my ( $self, $c ) = @_;

    croak "Not high enough level for that" unless $c->stash->{party}->level >= $c->config->{minimum_raid_level};

    my $town = $c->model('DBIC::Town')->find( { town_id => $c->req->param('town_id') } );

    croak "Invalid town id" unless $town;

    croak "Not next to that town" unless $c->stash->{party_location}->next_to( $town->location );
    
    my $start_sector = $c->model('DBIC::Dungeon_Grid')->find(
    	{
    		'dungeon.land_id' => $town->land_id,
    		'stairs_up' => 1,
    	},
    	{
    		join => {'dungeon_room' => 'dungeon'},
    	}
    );
    
    confess "Castle not found for town " . $town->id unless $start_sector;
    
    $c->stash->{party}->dungeon_grid_id($start_sector->id);
    $c->stash->{party}->update;
    
    $c->forward( '/panel/refresh', [ 'messages', 'party_status', 'map' ] );
}

sub old_raid : Local {
	my ( $self, $c ) = @_;
	my $town;
	
    my $turn_cost = round $town->prosperity / 4;

    if ( $turn_cost > $c->stash->{party}->turns ) {
        $c->stash->{error} = "You need at least $turn_cost turns to raid this town";
        $c->detach('/panel/refresh');
    }

    my $party_town = $c->model('DBIC::Party_Town')->find_or_create(
        {
            town_id  => $town->id,
            party_id => $c->stash->{party}->id,
        }
    );

    my $party_raid_factor =
        ( $c->stash->{party}->average_stat('intelligence') / 2 ) +
        $c->stash->{party}->average_stat('agility') +
        ( $c->stash->{party}->average_stat('divinity') / 2 );

    my $town_raid_factor = $town->prosperity + ( ( $town->prosperity / 4 ) * ( $party_town->raids_today || 0 ) );

    my $raid_factor = round $town_raid_factor - round $party_raid_factor;
    my $raid_roll   = Games::Dice::Advanced->roll('1d100');

    my $raid_quotient = $raid_factor - $raid_roll;

    my $base_gold    = $town->prosperity * 6;
    my $gold_to_gain = $base_gold + Games::Dice::Advanced->roll( '1d' . $base_gold );

    $c->log->debug( "Town Prosp: "
            . $town->prosperity
            . " Town Raid Factor: $town_raid_factor, Party Raid Factor: $party_raid_factor, Raid Factor: $raid_factor, Raid Roll: $raid_roll, "
            . "Raid Qiotient: $raid_quotient, Gold To Gain: $gold_to_gain" );

    my $raid_successful = 0;
    my $prestige_change = 0;
    my $turns_lost;

    given ($raid_quotient) {
        when ( $_ < -60 ) {

            # Success, no consequence
            $c->stash->{party}->gold( $c->stash->{party}->gold + $gold_to_gain );
            $c->stash->{messages} = ["You charge past the guards without anyone ever noticing you. You steal $gold_to_gain gold from the treasury"];
            $raid_successful = 1;
        }
        when ( $_ < -40 ) {

            # Success, but prestige reduced
            $c->stash->{party}->gold( $c->stash->{party}->gold + $gold_to_gain );
            $c->stash->{messages} =
                [     "You make it to the treasury and steal $gold_to_gain gold. On the way out, a guard spots you, and gives chase. You get "
                    . "away, but this will surely affect your prestige with the town." ];
            $raid_successful = 1;
            $prestige_change = -8;
        }
        when ( $_ < -20 ) {

            # Failure, prestige reduced
            $c->stash->{messages} =
                [     "You get halfway to the treasury only to run into a squard of guards. You turn on your heels, and run your hearts out, making "
                    . " it out of the gates before the guards can catch you. It's not too likely they'll want to see you back there any time soon" ];
            $prestige_change = -8;
        }
        default {

            # Failure and imprisonment
            $turns_lost = round $town->prosperity / 4;
            $turns_lost = 2 if $turns_lost < 2;

            $c->stash->{messages} =
                [     "You're just loading up on sacks of gold when the guards burst through the door. You've been caught red-handed! "
                    . "You're imprisoned for $turns_lost turns" ];

            $c->stash->{party}->turns( $c->stash->{party}->turns - $turns_lost );

            $prestige_change = -8;
        }
    }

    my $news_message;

    if ($raid_successful) {
        my $quest_messages = $c->forward( '/quest/check_action', [ 'town_raid', $town->id ] );

        if ($quest_messages) {
            push @{ $c->stash->{messages} }, @$quest_messages;
        }

        $news_message =
              'The party known as '
            . $c->stash->{party}->name
            . ' sucessfully raided the town of '
            . $town->town_name
            . " and got away with $gold_to_gain gold";
    }
    elsif ($turns_lost) {
        $news_message =
              'The party known as '
            . $c->stash->{party}->name
            . ' tried to raid the town of '
            . $town->town_name
            . " but were caught, and imprisioned!";
    }
    else {
        $news_message =
              'The party known as '
            . $c->stash->{party}->name
            . ' tried to raid the town of '
            . $town->town_name
            . ' but were intercepted by the '
            . 'guards and fled empty-handed';
    }

    $c->model('DBIC::Town_History')->create(
        {
            town_id => $town->id,
            day_id  => $c->stash->{today}->id,
            message => $news_message,
        }
    );

    $c->stash->{party}->turns( $c->stash->{party}->turns - $turn_cost );
    $c->stash->{party}->update;

    $party_town->raids_today( ( $party_town->raids_today || 0 ) + 1 );
    $party_town->prestige( $party_town->prestige + $prestige_change );
    $party_town->update;

    $c->forward( '/panel/refresh', [ 'messages', 'party_status' ] );
}

1;
