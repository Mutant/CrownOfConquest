package RPG::NewDay::Action::Mayor;
use Moose;

extends 'RPG::NewDay::Base';

use Data::Dumper;
use Games::Dice::Advanced;
use List::Util qw(sum shuffle);
use Math::Round qw(round);

with 'RPG::NewDay::Role::CastleGuardGenerator';

sub depends { qw/RPG::NewDay::Action::CreateDay RPG::NewDay::Action::Town RPG::NewDay::Action::Player RPG::NewDay::Action::Town_Loyalty/ }

sub run {
    my $self = shift;

    my $c = $self->context;

    my @towns = $c->schema->resultset('Town')->search(
        {},
        {
            prefetch => 'mayor',
        }
    );

    my @errors;
    foreach my $town (@towns) {
        eval {
            $self->process_town($town);
        };
        if ($@) {
            push @errors, "Error processing town " . $town->id . ": " . $@;
        }
    }

    $c->schema->resultset('Party_Town')->search->update( { tax_amount_paid_today => 0 } );

    $self->alert_parties_about_exceeding_mayor_limit;

    die join "\n", @errors if @errors;
}

sub process_town {
    my $self = shift;
    my $town = shift;

    my $c = $self->context;

    $self->context->logger->debug( "Processing mayor for town " . $town->id );

    # Reset tax modified flag
    $town->tax_modified_today(0);
    $town->update;

    my $mayor = $town->mayor;

    $mayor = $self->check_for_mayor_replacement( $town, $mayor );

    $self->refresh_mayor( $mayor, $town );

    if ( $town->pending_mayor ) {
        $self->check_for_pending_mayor_expiry($town);
    }

    if ( $mayor->is_npc ) {
        $self->context->logger->debug("Mayor is NPC");

        # Set default tax rates
        if ( $town->peasant_tax < 8 || $town->peasant_tax > 15 ) {
            $town->peasant_tax( Games::Dice::Advanced->roll('1d8') + 7 );
        }

        $town->sales_tax(10);
        $town->base_party_tax(20);
        $town->party_tax_level_step(30);
        $town->advisor_fee(0);
        $town->update;

        $self->check_for_npc_election($town);

        $self->check_for_allegiance_change($town);

        $self->train_guards($town);
    }

    my $revolt_started = $self->check_for_revolt($town);

    if ( $town->peasant_tax && !$town->peasant_state ) {
        $self->collect_tax( $town, $mayor );
    }

    $self->calculate_kingdom_tax($town);

    $self->generate_guards( $town->castle );
    $town->discard_changes;

    $self->pay_trap_maintenance($town);

    $self->calculate_approval($town);

    $self->check_if_election_needed($town);

    if ( !$revolt_started && $town->peasant_state ) {
        $self->process_revolt($town);
    }

    $self->gain_xp( $town, $mayor );

    $self->generate_advice($town);
}

sub collect_tax {
    my $self  = shift;
    my $town  = shift;
    my $mayor = shift;

    my $c = $self->context;

    my $bonus = 15 + ( $mayor->execute_skill( 'Leadership', 'town_peasant_tax' ) // 0 );
    my $roll = Games::Dice::Advanced->roll('2d30');

    $c->logger->debug( "Tax collection: bonus: $bonus, prosp: " . $town->prosperity . ", roll: $roll, tax: " . $town->peasant_tax );

    my $gold = int( ( $roll + $town->prosperity * $bonus ) * ( $town->peasant_tax / 100 ) ) * 10;
    $self->context->logger->debug("Collecting $gold peasant tax");
    $town->increase_gold($gold);
    $town->update;

    $c->schema->resultset('Town_History')->create(
        {
            town_id => $town->id,
            day_id  => $c->current_day->id,
            message => "The mayor collected $gold gold tax from the peasants",
        }
    );

    $town->add_to_history(
        {
            type    => 'income',
            value   => $gold,
            message => 'Peasant Tax',
            day_id  => $c->current_day->id,
        }
    );

}

sub calculate_approval {
    my $self = shift;
    my $town = shift;

    my $mayor = $town->mayor;

    return if ! $mayor || ! $self->context->yesterday;

    # Don't adjust approval if the mayoralty changed hands yesterday
    #  We do this by checking if there's a Party_Mayor_History record that
    #  starts or ends today. We don't care so much about NPCs
    my $changes = $self->context->schema->resultset('Party_Mayor_History')->search(
        {
            town_id => $town->id,
            -nest   => [
                { got_mayoralty_day  => $self->context->yesterday->id },
                { lost_mayoralty_day => $self->context->yesterday->id },
              ]
        }
    )->count;

    if ( $changes >= 1 ) {
        $self->context->logger->debug("Mayoralty changed hands $changes times today, not calculating approval");
        return;
    }

    my $party_town_rec = $self->context->schema->resultset('Party_Town')->find(
        { town_id => $town->id, },
        {
            select => [ { sum => 'tax_amount_paid_today' }, ],
            as => ['tax_collected'],
        }
    );

    my $town_raid_rec = $self->context->schema->resultset('Town_Raid')->find(
        {
            town_id => $town->id,
            day_id  => $self->context->yesterday->id,
        },
        {
            select => [ { sum => 'guards_killed' } ],
            as => ['guards_killed'],
        }
    );

    my $guards_killed = $town_raid_rec->get_column('guards_killed')  // 0;
    my $tax_collected = $party_town_rec->get_column('tax_collected') // 0;

    my $guards_killed_adjustment = -$guards_killed;

    my $party_tax_adjustment   = int $tax_collected / 100;
    my $peasant_tax_adjustment = -$town->peasant_tax / 2 - 1;

    my $creature_rec = $self->context->schema->resultset('Creature')->find(
        {
            'dungeon_room.dungeon_id' => $town->castle->id,
            'hit_points_current' => { '>', 0 },
        },
        {
            join => [ 'type', { 'creature_group' => { 'dungeon_grid' => 'dungeon_room' } } ],
            select => { sum => 'type.maint_cost' },
            as => 'cost_aggregate',
        }
    );

    my $creature_level = $creature_rec->get_column('cost_aggregate') || 0;

    #$self->context->logger->debug("Level aggregate: " . $creature_level);
    my $guards_hired_adjustment = int( $creature_level / ( $town->prosperity * 10 ) );

    my $garrison_chars_adjustment = 0;

    # Adjustment for garrison characters - not applied to npc mayors
    if ( !$town->mayor->is_npc ) {
        my $expected_garrison_chars_level = $town->expected_garrison_chars_level;

        my @garrison_chars = $self->context->schema->resultset('Character')->search(
            {
                status         => 'mayor_garrison',
                status_context => $town->id,
            }
        );

        my $actual_garrison_chars_level = 0;
        foreach my $char (@garrison_chars) {
            $actual_garrison_chars_level += $char->level;
        }

        #$self->context->logger->debug("Garrison expected: " . $expected_garrison_chars_level . "; actual: $actual_garrison_chars_level");

        $garrison_chars_adjustment = round( ( $actual_garrison_chars_level - $expected_garrison_chars_level ) / 10 );

        $garrison_chars_adjustment = 0 if $actual_garrison_chars_level >= 200;
    }

    my $charisma_adjustment = $mayor->execute_skill( 'Charisma', 'mayor_approval' ) // 0;

    # Runes adjustment
    my $expected_rune_level = $town->prosperity < 45 ? 0 : round $town->prosperity / 3;
    my $building   = $town->building;
    my $rune_level = 0;
    if ($building) {
        my @upgrades = $building->upgrades;
        foreach my $upgrade (@upgrades) {
            next unless $upgrade->type->name =~ /^Rune/;
            $rune_level += $upgrade->level;
        }
    }
    my $rune_adjustment = $rune_level - $expected_rune_level;

    # A random component to approval
    my $random_adjustment += Games::Dice::Advanced->roll('1d5') - 3;

    my $adjustment = $guards_killed_adjustment + $party_tax_adjustment +
      $peasant_tax_adjustment + $guards_hired_adjustment + $garrison_chars_adjustment + $charisma_adjustment
      + $rune_adjustment + $random_adjustment;

    $adjustment = -10 if $adjustment < -10;
    $adjustment = 10  if $adjustment > 10;

    $self->context->logger->debug( "Approval rating adjustment: $adjustment " .
          "[Guards Killed: $guards_killed_adjustment; Guards Hired: $guards_hired_adjustment; " .
          "Party Tax: $party_tax_adjustment; Peasant Tax: $peasant_tax_adjustment; Garrison Chars: $garrison_chars_adjustment; " .
          "Charisma: $charisma_adjustment; Rune Adjustment: $rune_adjustment; Random: $random_adjustment]" );

    $town->adjust_mayor_rating($adjustment);
    $town->update;

    $town->add_to_history(
        {
            type    => 'income',
            value   => $tax_collected,
            message => 'Party Entrance Tax',
            day_id  => $self->context->current_day->id,
        }
    );

}

sub check_for_revolt {
    my $self = shift;
    my $town = shift;

    return if defined $town->peasant_state && $town->peasant_state eq 'revolt';

    my $c = $self->context;

    my $start_revolt  = 0;
    my $revolt_reason = 'mayor';

    my $mayor = $town->mayor;

    if ( $town->mayor_rating < -30 ) {
        my $rating = $town->mayor_rating + 100;

        my $roll = Games::Dice::Advanced->roll('1d100');

        $start_revolt = 1 if $roll > $rating;
    }
    elsif ( $town->peasant_tax >= 35 ) {
        $c->logger->debug( "Starting revolt because peasant tax is " . $town->peasant_tax );

        $start_revolt = 1;
    }
    elsif ( $town->location->kingdom_id && $town->kingdom_loyalty < 0 && !$town->capital_of ) {
        my $rating = $town->kingdom_loyalty + 80;

        my $roll = Games::Dice::Advanced->roll('1d100');

        $start_revolt = 1 if $roll > $rating;
        $revolt_reason = 'kingdom';
    }
    elsif ( !$mayor->is_npc ) {

        # Check party is not over mayor limit (excluding towns already in revolt)
        my $party        = $mayor->party;
        my $partys_towns = $party->mayors->search_related(
            'mayor_of_town',
            {
                peasant_state => [ undef, { '!=', 'revolt' } ],
            },
        )->count;

        if ( $party->mayor_count_allowed < $partys_towns ) {
            $c->logger->debug( "Starting revolt as party has $partys_towns, which exceeded max of " . $party->mayor_count_allowed );
            $start_revolt = 1;
        }
    }

    if ($start_revolt) {
        $town->peasant_state('revolt');
        $town->update;

        $town->add_to_history(
            {
                day_id => $c->current_day->id,
                message => "The peasants have had enough of being treated poorly, and revolt against the $revolt_reason!",
            }
        );

        unless ( $mayor->is_npc ) {
            $c->schema->resultset('Party_Messages')->create(
                {
                    message => $mayor->character_name . " sends word that the peasants of " . $town->town_name . " have risen up in open rebellion"
                      . " against the $revolt_reason",
                    alert_party => 1,
                    party_id    => $mayor->party_id,
                    day_id      => $c->current_day->id,
                }
            );
        }
    }

    return $start_revolt;
}

sub process_revolt {
    my $self = shift;
    my $town = shift;

    return unless $town->peasant_state eq 'revolt';

    my $c = $self->context;

    my $castle      = $town->castle;
    my $guard_bonus = 0;

    if ($castle) {
        my $guards_rec = $self->context->schema->resultset('Creature')->find(
            {
                'dungeon_room.dungeon_id' => $town->castle->id,
            },
            {
                join => [ { 'creature_group' => { 'dungeon_grid' => 'dungeon_room' } }, 'type' ],
                select => [ { sum => 'type.level' } ],
                as => 'level_aggregate',
            }
        );

        $guard_bonus = int( $guards_rec->get_column('level_aggregate') // 0 ) / 100;
    }

    my $garrison_aggregate = $self->context->schema->resultset('Character')->search(
        {
            status         => 'mayor_garrison',
            status_context => $town->id,
        }
    )->count;

    my $garrison_bonus = int $garrison_aggregate / 15;

    my $prosp_penalty = int $town->prosperity / 10;

    my $kingdom_loyalty_penalty = 0;
    if ( $town->location->kingdom_id && $town->kingdom_loyalty < 0 ) {
        $kingdom_loyalty_penalty = abs int $town->kingdom_loyalty / 5;
    }

    my $mayor             = $town->mayor;
    my $negotiation_bonus = 0;
    if ($mayor) {
        $negotiation_bonus = $mayor->execute_skill( 'Negotiation', 'mayor_overthrow_check' ) // 0;
    }

    my $too_many_mayors_penalty = 0;
    if ( !$mayor->is_npc ) {

        # If the party is over their max mayor count, give a big penalty
        my $party = $mayor->party;
        $too_many_mayors_penalty = 40 if $party->mayor_count_allowed < $party->mayors->count;
    }

    $c->logger->debug( "Checking for overthrow of mayor; guard bonus: $guard_bonus; prosp penalty: $prosp_penalty; garrison bonus: $garrison_bonus;" .
          " kingdom loyalty penalty: $kingdom_loyalty_penalty; negotiation bonus: $negotiation_bonus; too many mayors penalty: $too_many_mayors_penalty" );

    my $roll = Games::Dice::Advanced->roll('1d100') + $guard_bonus - $prosp_penalty
      + $garrison_bonus - $kingdom_loyalty_penalty + $negotiation_bonus - $too_many_mayors_penalty;

    $c->logger->debug("Overthrow roll: $roll");

    if ( $roll < 20 ) {
        $mayor->lose_mayoralty;

        my $new_mayor = $self->create_mayor($town);

        $town->add_to_history(
            {
                day_id => $c->current_day->id,
                message => "The peasants overthrow Mayor " . $mayor->character_name . ". They replace " . $mayor->pronoun('objective') . ' with the ' .
                  ' much more agreeable ' . $new_mayor->character_name,
            }
        );

        if ( $mayor->party_id ) {
            $c->schema->resultset('Party_Messages')->create(
                {
                    message => $mayor->character_name . " was overthown by the peasants of " . $town->town_name . " and is no longer mayor. "
                      . ucfirst $mayor->pronoun('posessive-subjective') . " body has been interred in the town cemetery, and "
                      . $mayor->pronoun('posessive') . " may be ressurrected there.",
                    alert_party => 1,
                    party_id    => $mayor->party_id,
                    day_id      => $c->current_day->id,
                }
            );
        }

        $mayor->add_to_history(
            {
                day_id => $c->current_day->id,
                event => $mayor->character_name . " was killed in a rebellion by the peasants of " . $town->town_name,
            }
        );

        # Check for allegiance change now there's a new mayor
        $self->check_for_allegiance_change($town);

        return;
    }
    elsif ( $roll < 35 ) {

        # Peasants destroy some upgrades if some exist
        my $building = $town->building;

        if ( $building && $building->upgrades->count > 0 ) {
            my @upgrades = $building->upgrades;

            if (@upgrades) {
                my ($upgrade) = ( shuffle @upgrades )[0];
                my $damage = Games::Dice::Advanced->roll('1d3');
                $damage = $upgrade->level if $damage > $upgrade->level;
                $upgrade->level( $upgrade->level - $damage );
                $upgrade->update;

                $town->add_to_history(
                    {
                        day_id => $c->current_day->id,
                        message => "The peasants storm the town hall, damaging some of the town's defences!",
                    }
                );

                $town->add_to_history(
                    {
                        day_id => $c->current_day->id,
                        message => "The revolting peasants have removed $damage levels from our " . $upgrade->type->name . " add-on",
                        type => 'mayor_news',
                    }
                );

                return;
            }
        }
    }
    elsif ( $roll > 80 ) {
        $town->increase_mayor_rating(19);
        $town->peasant_state(undef);
        $town->update;

        $town->add_to_history(
            {
                day_id => $c->current_day->id,
                message => "Mayor " . $mayor->character_name . " and his guards crush the peasant rebellion. The troublemakers are taken out back and given " .
                  "a stern talking to",
            }
        );

        if ( $mayor->party_id ) {
            $c->schema->resultset('Party_Messages')->create(
                {
                    message => $mayor->character_name . " reports " . lcfirst $mayor->pronoun('subjective') . "'s successfully crushed the peasant rebellion in"
                      . $town->town_name,
                    alert_party => 1,
                    party_id    => $mayor->party_id,
                    day_id      => $c->current_day->id,
                }
            );
        }

        return;
    }

    $town->add_to_history(
        {
            day_id  => $c->current_day->id,
            message => "The peasants are still in revolt!",
        }
    );
}

sub check_for_pending_mayor_expiry {
    my $self = shift;
    my $town = shift;

    # See if the pending mayor's been waiting for too long to accept mayoralty
    if ( DateTime->compare( $town->pending_mayor_date, DateTime->now()->subtract( hours => 24 ) ) == -1 ) {
        $town->pending_mayor(undef);
        $town->pending_mayor_date(undef);
        $town->update;
    }
}

sub refresh_mayor {
    my $self  = shift;
    my $mayor = shift;
    my $town  = shift;

    return if ! $mayor;

    my $cg;

    if (defined $mayor->creature_group_id) {
        $cg = $mayor->creature_group;

        # They miss out if they happen to be in combat
        return if $cg && $cg->in_combat;
    }

    # Heal NPC mayor to max hps if they're not dead, or they were killed, but no one took over
    if ( $mayor->is_npc && ( !$mayor->is_dead || !$town->pending_mayor ) ) {
        $mayor->hit_points( $mayor->max_hit_points );
        $mayor->update;
    }

    # Mayor gets items auto-repaired, and ammo stocked up
    my @items = $mayor->items;
    foreach my $item (@items) {
        next unless $item->equipped;

        if ( my $variable = $item->variable_row('Durability') ) {
            $variable->item_variable_value( $variable->max_value );
            $variable->update;
        }

        if ( $item->item_type->category->item_category eq 'Ranged Weapon' ) {
            my @ammo = $mayor->ammunition_for_item($item);
            my $total_ammo = ( sum map { $_ && $_->{quantity} } @ammo ) // 0;

            if ( $total_ammo < 100 ) {

                # Create some more ammo
                my $ammunition_item_type_id = $item->item_type->attribute('Ammunition')->value;

                my $new_ammo = $self->context->schema->resultset('Items')->create(
                    {
                        item_type_id => $ammunition_item_type_id,
                        character_id => $mayor->id,
                    },
                );

                $mayor->add_item_to_grid($new_ammo);

                $new_ammo->variable( 'Quantity', 200 );
            }
        }
    }

    # Res dead garrison characters
    my @dead_garrison_chars = $self->context->schema->resultset('Character')->search(
        {
            status         => 'mayor_garrison',
            status_context => $town->id,
            hit_points     => { '<=', 0 },
        }
    );

    if (@dead_garrison_chars) {
        my $hist_rec = $self->context->schema->resultset('Town_History')->find_or_create(
            {
                town_id => $town->id,
                day_id  => $self->context->current_day->id,
                type    => 'expense',
                message => 'Town Garrison Healing',
            }
        );

        my $to_spend = $town->character_heal_budget - ( $hist_rec->value // 0 );
        $to_spend = $town->gold if $to_spend > $town->gold;

        my $spent     = 0;
        my $res_count = 0;

        foreach my $char (@dead_garrison_chars) {
            my $cost = $char->resurrect_cost;
            if ( $cost <= $to_spend ) {
                $char->resurrect( $town, 0 );
                $to_spend -= $cost;
                $spent += $cost;
                $self->context->logger->debug( "Resurrected town garrison char " . $char->id . " for the cost of $cost" );
                $town->decrease_gold($cost);
                $res_count++;
            }
        }

        $town->update;

        $town->add_to_history(
            {
                type => 'mayor_news',
                message => "The town healer resurrected $res_count town garrison characters at the cost of $spent gold.",
                day_id => $self->context->current_day->id,
            }
        );

        $hist_rec->increase_value($spent);
        $hist_rec->update;
    }

    # Auto-heal garrison & mayor if necessary
    $cg->auto_heal('new day') if $cg;
}

sub check_for_npc_election {
    my $self = shift;
    my $town = shift;

    return if $town->current_election || !$town->mayor;

    return unless Games::Dice::Advanced->roll('1d100') <= 1;

    my $days = Games::Dice::Advanced->roll('1d6') + 2;

    $self->context->logger->debug( "NPC Mayor in town " . $town->id . " schedules election for $days days time" );
    $self->context->schema->resultset('Election')->schedule( $town, $days );
}

sub check_if_election_needed {
    my $self = shift;
    my $town = shift;

    return if !$town->last_election || $town->current_election;

    my $days_since_last_election = $self->context->current_day->day_number - $town->last_election;

    if ( $days_since_last_election == 12 ) {

        # Give party a warning
        my $mayor = $town->mayor;
        return if $mayor->is_npc;

        my $party = $mayor->party;
        $party->add_to_messages(
            {
                day_id      => $self->context->current_day->id,
                alert_party => 1,
                message => "The town of " . $town->town_name . " hasn't had an election for $days_since_last_election days. The towns people expect one soon!",
            }
        );

        return;
    }

    if ( $days_since_last_election >= 15 && $days_since_last_election % 3 == 0 ) {
        $town->decrease_mayor_rating(20);
        $town->update;

        $town->add_to_history(
            {
                day_id => $self->context->current_day->id,
                message => "There hasn't been an election in $days_since_last_election days! The peasants demand their right to vote be honoured",
            }
        );

        my $mayor = $town->mayor;
        return if $mayor->is_npc;

        my $party = $mayor->party;
        $party->add_to_messages(
            {
                day_id      => $self->context->current_day->id,
                alert_party => 1,
                message => "The town of " . $town->town_name . " hasn't had an election for $days_since_last_election days. The towns people are extremely upset that one hasn't been called!",
            }
        );
    }
}

sub generate_advice {
    my $self  = shift;
    my $town  = shift;
    my $check = shift;

    my $advisor_fee = $town->advisor_fee;
    $self->context->logger->debug( "gold: " . $town->gold );

    if ( $town->gold < $advisor_fee ) {
        $advisor_fee = $town->gold;
    }

    $town->decrease_gold($advisor_fee);
    $town->update;

    $town->add_to_history(
        {
            type    => 'expense',
            value   => $advisor_fee,
            message => 'Advisor Fee',
            day_id  => $self->context->current_day->id,
        }
    );

    my $advice_chance = int $advisor_fee / ( $town->prosperity / 10 );

    if ( Games::Dice::Advanced->roll('1d100') > $advice_chance ) {

        # No advice given
        return;
    }

    my @checks;
    if ( defined $check ) {
        @checks = ($check);
    }
    else {
        @checks = qw/guards peasant_tax sales_tax garrison election approval revolt kingdom_loyalty runes/;
        @checks = shuffle @checks;
    }

    my $advice;
    for (@checks) {

        # Do they need more guards?
        if ( $_ eq 'guards' ) {
            my $castle = $town->castle;
            next unless $castle;

            my $creature_rec = $self->context->schema->resultset('Creature')->find(
                {
                    'dungeon_room.dungeon_id' => $town->castle->id,
                },
                {
                    join => [ 'type', { 'creature_group' => { 'dungeon_grid' => 'dungeon_room' } } ],
                    select => { sum => 'type.level' },
                    as => 'level_aggregate',
                }
            );

            my $creature_level = $creature_rec->get_column('level_aggregate') || 0;

            if ( $creature_level / $town->prosperity + 30 < 4 ) {
                $advice = "The townsfolk don't feel safe, perhaps you should hire some more guards";
                last;
            }
        }

        # Is peasant tax too high?
        elsif ( $_ eq 'peasant_tax' ) {
            if ( $town->peasant_tax > 25 ) {
                $advice = "The taxes seem very high, the peasants are not happy.";
                last;
            }
        }

        # Is sales tax too high?
        elsif ( $_ eq 'sales_tax' ) {
            if ( $town->sales_tax > 25 ) {
                $advice = "The local merchants are complaining that the sales tax is putting them out of business. Perhaps you should reduce it. ";
                last;
            }
        }

        # Do they need more garrison chars
        elsif ( $_ eq 'garrison' ) {
            my $garrison_char_rec = $self->context->schema->resultset('Character')->find(
                {
                    status         => 'mayor_garrison',
                    status_context => $town->id,
                },
                {
                    select => { sum => 'level' },
                    as => 'level_aggregate',
                }
            );

            my $level_aggr = $garrison_char_rec->get_column('level_aggregate') || 0;

            if ( $town->expected_garrison_chars_level > $level_aggr ) {
                $advice = "You could use some more protection. Adding more characters to the town's garrison will give you an edge";
                last;
            }
        }

        # Does an election need to be scheduled
        elsif ( $_ eq 'election' ) {
            next unless $town->last_election;
            my $days_since_last_election = $self->context->current_day->day_number - $town->last_election;
            if ( $days_since_last_election >= 12 ) {
                $advice = "The town hasn't run an election in a while - schedule one before the towns people become restless";
                last;
            }
        }

        elsif ( $_ eq 'approval' ) {
            if ( $town->mayor_rating < -50 ) {
                $advice = "Your approval rating is very low. Hire more guards, lower the taxes or schedule an election to help appease the peasants";
                last;
            }
        }

        elsif ( $_ eq 'revolt' ) {
            if ( $town->peasant_state eq 'revolt' ) {
                $advice = "The peasants are in revolt - it must be crushed! Garrison more characters and hire more guards";
                last;
            }
        }

        elsif ( $_ eq 'kingdom_loyalty' ) {
            if ( $town->location->kingdom_id && $town->kingdom_loyalty < 0 ) {
                $advice = "The towns people are not very loyal to the town's kingdom. Make sure the town is joined to the kingdom's capital by claimed land";
                last;
            }
        }

        elsif ( $_ eq 'runes' ) {
            last if $town->prosperity < 35;
            my $building = $town->building;
            if ( !$building ) {
                $advice = "The town does not have a building. Construct one to help defend it";
                last;
            }
            my @upgrades = $building->upgrades;
            my $rune_level;
            foreach my $upgrade (@upgrades) {
                next unless $upgrade->type =~ /^Rune/;
                $rune_level += $upgrade->level;
            }

            next if $rune_level >= 30;

            if ( $rune_level < round( $town->prosperity / 3 ) ) {
                $advice = "The town does not have enough Rune add-ons to its building. Building more of these will greating improve the town's defences.";
                last;
            }

        }
    }

    $advice ||= "No advice necessary - you're doing a great job!";

    $town->add_to_history(
        {
            type    => 'advice',
            message => $advice,
            day_id  => $self->context->current_day->id,
        }
    );

}

sub calculate_kingdom_tax {
    my $self = shift;
    my $town = shift;

    my $c = $self->context;

    my $kingdom = $town->location->kingdom;

    return if !$kingdom || $kingdom->mayor_tax == 0;

    my $income = $town->find_related(
        'history',
        {
            day_id => $c->current_day->id,
            type   => 'income',
        },
        {
            'select' => [ { sum => 'value' } ],
            'as' => ['income'],
        }
    )->get_column('income');

    my $kingdom_tax = round( $income * $kingdom->mayor_tax / 100 );

    $town->decrease_gold($kingdom_tax);
    $town->update;

    $town->add_to_history(
        {
            type    => 'expense',
            value   => $kingdom_tax,
            message => 'Kingdom Tax',
            day_id  => $c->current_day->id,
        }
    );

    $kingdom->increase_gold($kingdom_tax);
    $kingdom->update;

    $kingdom->add_to_messages(
        {
            message => "The mayor of " . $town->town_name . " paid us $kingdom_tax gold in tax",
            day_id => $c->current_day->id,
        }
    );
}

# Allegiance has a chance of changing if town is more loyal to another kingdom
sub check_for_allegiance_change {
    my $self = shift;
    my $town = shift;

    my $c = $self->context;

    # Free cities don't change their loyalty of their own accord
    return unless $town->location->kingdom_id;

    my $current_loyalty    = $town->kingdom_loyalty;
    my $current_kingdom_id = $town->location->kingdom_id;

    # Make sure it's a fair comparison (i.e. everything they have a loyalty rating for
    #  could be in the negatives).
    $town->create_kingdom_town_recs;

    my $max_loyalty_rs = $c->schema->resultset('Kingdom_Town')->search(
        {
            town_id => $town->id,
        },
        {
            select => [
                { max => 'loyalty' }
            ],
            as => 'loyalty',
        }
    );

    my @highest_loyalty_kingdoms = $c->schema->resultset('Kingdom_Town')->search(
        {
            town_id => $town->id,
            loyalty => { '=', $max_loyalty_rs->get_column('loyalty')->as_query },
        },
    );

    my $highest_loyalty_kingdom = ( shuffle @highest_loyalty_kingdoms )[0];

    # Don't change if nothing is higher than current loyalty
    if ( $highest_loyalty_kingdom->loyalty >= $current_loyalty ) {
        my $loyalty_diff = $highest_loyalty_kingdom->loyalty - $current_loyalty;

        my $change_chance = round( $loyalty_diff / 3 );

        if ( Games::Dice::Advanced->roll('1d100') <= $change_chance ) {
            $town->change_allegiance( $highest_loyalty_kingdom->kingdom );
            return;
        }
    }

    # Also a chance they go neutral
    if ( Games::Dice::Advanced->roll('1d100') <= 8 ) {
        $town->change_allegiance(undef);
    }
}

sub pay_trap_maintenance {
    my $self = shift;
    my $town = shift;

    my $c = $self->context;

    if ( $town->trap_level > 0 ) {
        my $maint_cost = $town->trap_level * $c->config->{town_trap_maint_cost};

        if ( $town->gold >= $maint_cost ) {
            $town->decrease_gold($maint_cost);

            $town->add_to_history(
                {
                    type    => 'expense',
                    value   => $maint_cost,
                    message => 'Trap Maintenance',
                    day_id  => $c->current_day->id,
                }
            );
        }
        else {
            $town->decrement_trap_level;
        }

        $town->update;
    }
}

sub train_guards {
    my $self = shift;
    my $town = shift;

    my $minimum_level_aggregate = $town->prosperity * 6 + Games::Dice::Advanced->roll('1d500');

    my $creature_guard_types = $self->creature_guard_types;

    my %current_hires;
    my $level_aggregate = 0;

    foreach my $type (@$creature_guard_types) {
        my $guards_to_hire = $self->context->schema->resultset('Town_Guards')->find_or_create(
            {
                town_id          => $town->id,
                creature_type_id => $type->id,
            }
        );

        $current_hires{ $type->id } = $guards_to_hire;
        $level_aggregate += $type->level * ( $guards_to_hire->amount // 0 );
    }

    my @sorted_types = sort { $b->hire_cost <=> $a->hire_cost } @$creature_guard_types;

    my $spent = 0;
    while ( $level_aggregate <= $minimum_level_aggregate ) {
        my $hired = 0;
        foreach my $type (@sorted_types) {
            next if $town->gold < $type->hire_cost;

            $current_hires{ $type->id }->increment_amount;
            $current_hires{ $type->id }->update;

            $spent += $type->hire_cost;

            $town->decrease_gold( $type->hire_cost );
            $town->update;

            $level_aggregate += $type->level;

            $hired = 1;

            last;
        }

        last if !$hired;
    }

    if ($spent) {
        $town->add_to_history(
            {
                day_id  => $self->context->current_day->id,
                type    => 'expense',
                message => 'Guard Training',
                value   => $spent,
            },
        );
    }

}

sub creature_guard_types {
    my $self = shift;

    my $c = $self->context;

    $self->{creature_guard_types} //= [ $c->schema->resultset('CreatureType')->search(
            {
                'category.name' => 'Guard',
            },
            {
                join     => 'category',
                order_by => 'level',
            }
    ) ];

    return $self->{creature_guard_types};
}

sub gain_xp {
    my $self  = shift;
    my $town  = shift;
    my $mayor = shift;

    return if $mayor->is_npc;

    my $c = $self->context;

    my $xp = round( $town->prosperity / 3 ) + round( $town->mayor_rating / 5 )
      + ( $mayor->execute_skill( 'Charisma', 'mayor_xp_gain' ) // 0 ) + ( $mayor->execute_skill( 'Leadership', 'mayor_xp_gain' ) // 0 )
      + Games::Dice::Advanced->roll('2d10');

    return if $xp <= 0;

    my $details = $mayor->xp( $mayor->xp + $xp );
    $mayor->update;

    my $message = RPG::Template->process(
        $c->config,
        'party/xp_gain.html',
        {
            character        => $mayor,
            xp_awarded       => $xp,
            level_up_details => $details,
            reason           => 'from being mayor',
        },
    );

    $town->add_to_history(
        {
            type    => 'mayor_news',
            message => $message,
            day_id  => $c->current_day->id,
        }
    );

}

sub alert_parties_about_exceeding_mayor_limit {
    my $self = shift;

    my $c = $self->context;

    # Find parties that have at least one mayor
    my @parties = $c->schema->resultset('Party')->search(
        {
            defunct => undef,
        },
    );

    foreach my $party (@parties) {
        my $mayor_count   = $party->mayors->count;
        my $count_allowed = $party->mayor_count_allowed;
        if ( $count_allowed < $mayor_count ) {

            # They have too many mayors - alert them
            $party->add_to_messages(
                {
                    message => "We have $mayor_count mayors, which exceeds our maximum of $count_allowed. We should relinquish " .
                      "the mayoralties of some of our towns, or risk revolts!",
                    alert_party => 1,
                    day_id      => $c->current_day->id,
                }
            );
        }
    }
}

1;
