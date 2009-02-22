package RPG::C::Combat;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use Carp;

use Games::Dice::Advanced;
use List::Util qw(shuffle);
use DateTime;

sub auto : Private {
    my ( $self, $c ) = @_;

    # Load combat_log into stash (if we're in combat)
    if ( $c->stash->{party}->in_combat_with ) {
        $c->stash->{combat_log} = $c->model('DBIC::Combat_Log')->find(
            {
                party_id          => $c->stash->{party}->id,
                creature_group_id => $c->stash->{party}->in_combat_with,
                land_id           => $c->stash->{party_location}->id,
                encounter_ended   => undef,
            },
        );

        unless ( $c->stash->{combat_log} ) {
            $c->error('No combat log found for in progress combat');
            return 0;
        }
    }

    return 1;
}

sub end : Private {
    my ( $self, $c ) = @_;

    # Save any changes to the combat log
    $c->stash->{combat_log}->update if $c->stash->{combat_log};

    $c->forward('/end');    # TODO: can chaining take care of this?
}

# Check to see if creatures attack party (if there are any in their current sector)
sub check_for_attack : Local {
    my ( $self, $c, $new_land ) = @_;

    # See if party is in same location as a creature
    my $creature_group = $new_land->available_creature_group;

    # If there are creatures here, check to see if we go straight into combat
    if ( $creature_group && $creature_group->number_alive > 0 ) {
        $c->stash->{creature_group} = $creature_group;

        if ( $creature_group->initiate_combat( $c->stash->{party} ) ) {
            $c->stash->{party}->in_combat_with( $creature_group->id );
            $c->stash->{party}->update;
            $c->stash->{creatures_initiated} = 1;

            $c->forward( 'create_combat_log', [ $creature_group, 'creatures' ] );

            return $creature_group;
        }
    }
}

sub party_attacks : Local {
    my ( $self, $c ) = @_;

    my $creature_group = $c->stash->{party_location}->available_creature_group;

    $c->forward('execute_attack', [$creature_group]);

}

sub execute_attack : Private {
    my ( $self, $c, $creature_group ) = @_;

    if ($creature_group) {
        $c->stash->{creature_group} = $creature_group;

        $c->stash->{party}->in_combat_with( $creature_group->id );
        $c->stash->{party}->update;

        $c->forward( 'create_combat_log', [ $creature_group, 'party' ] );

        $c->forward( '/panel/refresh', [ 'messages', 'party' ] );
    }
    else {
        $c->stash->{messages} = "The creatures have moved, or have been attacked by someone else.";
        $c->forward( '/panel/refresh', ['messages'] );
    }

}

sub create_combat_log : Private {
    my ( $self, $c, $creature_group, $initiated_by ) = @_;

    my $current_day = $c->model('DBIC::Day')->find(
        {},
        {
            select => { max => 'day_number' },
            as     => 'current_day'
        },
    )->get_column('current_day');

    $c->stash->{combat_log} = $c->model('DBIC::Combat_Log')->create(
        {
            party_id             => $c->stash->{party}->id,
            creature_group_id    => $creature_group->id,
            land_id              => $c->stash->{party_location}->id,
            encounter_started    => DateTime->now(),
            combat_initiated_by  => $initiated_by,
            party_level          => $c->stash->{party}->level,
            creature_group_level => $creature_group->level,
            game_day             => $current_day,
        },
    );
}

sub main : Local {
    my ( $self, $c ) = @_;

    my $creature_group = $c->stash->{creature_group};
    unless ($creature_group) {
        $creature_group =
            $c->model('DBIC::CreatureGroup')
            ->find( { creature_group_id => $c->stash->{party}->in_combat_with, }, { prefetch => { 'creatures' => 'type' }, }, );
    }

    if ( $c->stash->{combat_complete} ) {
        $c->forward('/combat/finish');
    }

    my $orb;
    if ( $c->stash->{creatures_initiated} && ! $c->stash->{party}->dungeon_grid_id ) {
        $orb = $c->stash->{party_location}->orb;
    }

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'combat/main.html',
                params   => {
                    creature_group      => $creature_group,
                    creatures_initiated => $c->stash->{creatures_initiated},
                    combat_messages     => $c->stash->{combat_messages},
                    combat_complete     => $c->stash->{combat_complete},
                    party_dead          => $c->stash->{party}->defunct ? 1 : 0,
                    orb                 => $orb,
                    in_dungeon          => $c->stash->{party}->dungeon_grid_id ? 1 : 0,
                },
                return_output => 1,
            }
        ]
    );
}

sub select_action : Local {
    my ( $self, $c ) = @_;

    my $character = $c->model('DBIC::Character')->find( $c->req->param('character_id') );

    $character->last_combat_action( $c->req->param('action') );
    $character->update;

    # Remove empty strings
    my @action_params = grep { $_ ne '' } $c->req->param('action_param');

    if ( !@action_params ) {
        delete $c->session->{combat_action_param}{ $c->req->param('character_id') };
    }
    elsif ( scalar @action_params == 1 ) {
        $c->session->{combat_action_param}{ $c->req->param('character_id') } = $action_params[0];
    }
    else {
        $c->session->{combat_action_param}{ $c->req->param('character_id') } = \@action_params;
    }

    $c->forward( '/panel/refresh', ['messages'] );
}

sub fight : Local {
    my ( $self, $c ) = @_;
    
    $c->stash->{creature_group} = $c->model('DBIC::CreatureGroup')->get_by_id( $c->stash->{party}->in_combat_with );
      
    # Never flee if there's an orb here... 
    if (! $c->stash->{party_location}->orb && $c->forward('check_for_creature_flee')) {
        $c->detach('creatures_flee');
    }
      
    $c->forward('execute_round');
    
}

sub check_for_creature_flee : Private {
    my ( $self, $c ) = @_;
    
    # See if the creatures want to flee... check this every 3 rounds
    #  Only flee if cg level is lower than party
    $c->log->debug("Checking for creature flee");
    $c->log->debug("Round: " . $c->stash->{combat_log}->rounds);
    $c->log->debug("CG level: " . $c->stash->{creature_group}->level);
    $c->log->debug("Party level: " . $c->stash->{party}->level);
    
    if ( $c->stash->{combat_log}->rounds != 0 && $c->stash->{combat_log}->rounds % 3 == 0 ) {
        if ( $c->stash->{creature_group}->level < $c->stash->{party}->level-2) {
            my $chance_of_fleeing =
                ( $c->stash->{party}->level - $c->stash->{creature_group}->level ) * $c->config->{chance_creatures_flee_per_level_diff};
    
            $c->log->debug("Chance of creatures fleeing: $chance_of_fleeing");
    
            if ( $chance_of_fleeing >= Games::Dice::Advanced->roll('1d100') ) {
                return 1;
            }
        }
    }
    
    return 0;
}

sub execute_round : Private {
    my ( $self, $c ) = @_;    
    
    # Process magical effects
    $c->forward('process_effects');

    my @creatures  = $c->stash->{creature_group}->creatures;
    my @characters = $c->stash->{party}->characters;

    # Compute af/df for each participant. Only do this once per combat since it won't change
    $c->forward( 'calculate_factors', [ \@characters, \@creatures ] );

    # Get list of combatants, modified for changes in attack frequency, and radomised in order
    my $combatants = $c->forward( 'get_combatant_list', [ \@characters, \@creatures ] );

    my @combat_messages;

    foreach my $combatant (@$combatants) {
        next if $combatant->is_dead;

        my $action_result;
        if ( $combatant->is_character ) {
            $action_result = $c->forward( 'character_action', [ $combatant, $c->stash->{creature_group} ] );
        }
        else {
            $action_result = $c->forward( 'creature_action', [ $combatant, $c->stash->{party} ] );
        }

        if ($action_result) {
            if ( ref $action_result ) {
                my ( $target, $damage ) = @$action_result;

                push @combat_messages,
                    {
                    attacker        => $combatant,
                    defender        => $target,
                    defender_killed => $target->is_dead,
                    damage          => $damage || 0,
                    };
            }
            else {
                push @combat_messages, $action_result;
            }
        }

        last if $c->stash->{combat_complete} || $c->stash->{party}->defunct;
    }

    push @{ $c->stash->{combat_messages} },
        $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'combat/message.html',
                params   => {
                    combat_messages => \@combat_messages,
                    combat_complete => $c->stash->{combat_complete},
                },
                return_output => 1,
            }
        ]
        );

    $c->stash->{party}->turns( $c->stash->{party}->turns - 1 );
    $c->stash->{party}->update;

    $c->stash->{combat_log}->rounds( $c->stash->{combat_log}->rounds + 1 );

    $c->forward( '/panel/refresh', [ 'messages', 'party', 'party_status' ] );
}

sub calculate_factors : Private {
    my ( $self, $c, $characters, $creatures ) = @_;

    foreach my $combatant ( @$characters, @$creatures ) {
        next if $combatant->is_dead;

        my $type = $combatant->is_character ? 'character' : 'creature';

        unless ( defined $c->session->{combat_factors}{$type}{ $combatant->id }{af} ) {
            $c->session->{combat_factors}{$type}{ $combatant->id }{af} = $combatant->attack_factor;
            $c->log->debug( "Calculating attack factor for " . $combatant->name . " - " . $combatant->id );
        }

        unless ( defined $c->session->{combat_factors}{$type}{ $combatant->id }{df} ) {
            $c->session->{combat_factors}{$type}{ $combatant->id }{df} = $combatant->defence_factor;
            $c->log->debug( "Calculating defence factor for " . $combatant->name . " - " . $combatant->id );
        }
    }
}

sub character_action : Private {
    my ( $self, $c, $character, $creature_group ) = @_;

    my ( $creature, $damage );

    my %creatures = map { $_->id => $_ } $creature_group->creatures;

    if ( $character->last_combat_action eq 'Attack' ) {

        # If they've selected a target, make sure it's still alive
        my $targetted_creature = $c->session->{combat_action_param}{ $character->id };

        #warn Dumper $targetted_creature;
        if ( $targetted_creature && $creatures{$targetted_creature} && !$creatures{$targetted_creature}->is_dead ) {
            $creature = $creatures{$targetted_creature};
        }

        # If we don't have a target, choose one randomly
        unless ($creature) {
            do {
                my @ids = shuffle keys %creatures;
                $creature = $creatures{ $ids[0] };
            } while ( $creature->is_dead );
        }

        $damage = $c->forward( 'attack', [ $character, $creature ] );

        # Store damage done for XP purposes
        $c->session->{damage_done}{ $character->id } += $damage unless ref $damage;

        # If creature is now dead, see if any other creatures are left alive.
        #  If not, combat is over.
        if ( $creature->is_dead && $creature_group->number_alive == 0 ) {

            # We don't actually do any of the stuff to complete the combat here, so a
            #  later action can still display monsters, messages, etc.
            $c->stash->{combat_log}->outcome('party_won');
            $c->stash->{combat_log}->encounter_ended( DateTime->now() );

            $c->stash->{combat_complete} = 1;
        }

        return [ $creature, $damage ];
    }
    elsif ( $character->last_combat_action eq 'Cast' ) {
        my $message =
            $c->forward( '/magic/cast',
            [ $character, $c->session->{combat_action_param}{ $character->id }[0], $c->session->{combat_action_param}{ $character->id }[1], ],
            );

        # Since effects could have changed an af or df, we delete any id's in the cache matching the second param
        #  (the target's id) and then recompute.
        my $target = $c->session->{combat_action_param}{ $character->id }[1];
        my @cached_combatant_ids = ( keys %{ $c->session->{combat_factors}{character} }, keys %{ $c->session->{combat_factors}{creature} }, );

        $c->log->debug("Deleting combat factor cache for target id $target");

        foreach my $combatant_id (@cached_combatant_ids) {
            delete $c->session->{combat_factors}{character}{$combatant_id}
                if $combatant_id == $target;
            delete $c->session->{combat_factors}{creature}{$combatant_id}
                if $combatant_id == $target;
        }

        $c->forward( 'calculate_factors', [ [ $c->stash->{party}->characters ], [ $creature_group->creatures ] ] );

        $character->last_combat_action('Defend');
        $character->update;

        $c->stash->{combat_log}->spells_cast( $c->stash->{combat_log}->spells_cast + 1 );

        return $message;
    }
}

sub creature_action : Private {
    my ( $self, $c, $creature, $party ) = @_;

    my @characters = sort { $a->party_order <=> $b->party_order } $party->characters;
    @characters = grep { !$_->is_dead } @characters;    # Get rid of corpses

    # Figure out whether creature will target front or back rank
    my $rank_pos = $c->stash->{party}->rank_separator_position;
    unless ( $rank_pos == scalar @characters ) {
        my $rank_roll = Games::Dice::Advanced->roll('1d100');
        if ( $rank_roll <= RPG->config->{front_rank_attack_chance} ) {

            # Remove everything but front rank
            splice @characters, $rank_pos;
        }
        else {

            # Remove everything but back rank
            splice @characters, 0, $rank_pos;
        }
    }

    # Go back to original list if there's nothing in characters (i.e. there are only dead (or no) chars in this rank)
    @characters = $party->characters unless scalar @characters > 0;

    my $character;
    do {
        my $rand = int rand( $#characters + 1 );
        $character = $characters[$rand];
    } while ( $character->is_dead );

    my $defending = $character->last_combat_action eq 'Defend' ? 1 : 0;

    # Count number of times attacked for XP purposes
    $c->session->{attack_count}{ $character->id }++;

    my $damage = $c->forward( 'attack', [ $creature, $character, $defending ] );

    # Check for wiped out party
    if ( $character->is_dead && $party->number_alive == 0 ) {
        $c->stash->{combat_log}->outcome('creatures_won');
        $c->stash->{combat_log}->encounter_ended( DateTime->now() );

        $party->defunct( DateTime->now() );
        $party->update;

        #$c->stash->{party_dead} = 1;
    }

    return [ $character, $damage ];
}

sub get_combatant_list : Private {
    my ( $self, $c, $characters, $creatures ) = @_;

    my @combatants;
    foreach my $character (@$characters) {
        my @attack_history;
        @attack_history = @{ $c->session->{attack_history}{character}{ $character->id } }
            if $c->session->{attack_history}{character}{ $character->id };

        my $number_of_attacks = $character->number_of_attacks(@attack_history);

        push @attack_history, $number_of_attacks;

        $c->session->{attack_history}{character}{ $character->id } = \@attack_history;

        for ( 1 .. $number_of_attacks ) {
            push @combatants, $character;
        }
    }

    foreach my $creature (@$creatures) {
        my @attack_history = @{ $c->session->{attack_history}{creature}{ $creature->id } }
            if $c->session->{attack_history}{creature}{ $creature->id };

        my $attack_allowed = $creature->is_attack_allowed(@attack_history);

        push @attack_history, $attack_allowed;

        $c->session->{attack_history}{creature}{ $creature->id } = \@attack_history;

        push @combatants, $creature if $attack_allowed;
    }

    @combatants = shuffle @combatants;

    return \@combatants;
}

sub attack : Private {
    my ( $self, $c, $attacker, $defender, $defending ) = @_;

    if ( my $attack_error = $attacker->execute_attack ) {
        $c->log->debug( "Attacker " . $attacker->name . " wasn't able to attack defender " . $defender->name . " Error:" . Dumper $attack_error);
        return $attack_error;
    }

    my $a_roll = Games::Dice::Advanced->roll( '1d' . RPG->config->{attack_dice_roll} );
    my $d_roll = Games::Dice::Advanced->roll( '1d' . RPG->config->{defence_dice_roll} );

    my $defence_bonus = $defending ? RPG->config->{defend_bonus} : 0;

    my $af = $c->session->{combat_factors}{ $attacker->is_character ? 'character' : 'creature' }{ $attacker->id }{af};
    my $df = $c->session->{combat_factors}{ $defender->is_character ? 'character' : 'creature' }{ $defender->id }{df};

    my $aq = $af - $a_roll;
    my $dq = $df + $defence_bonus - $d_roll;

    $c->log->debug( "Executing attack. Attacker: " . $attacker->name . ", Defender: " . $defender->name );

    $c->log->debug("Attack:  Factor: $af Roll: $a_roll  Quotient: $aq");
    $c->log->debug("Defence: Factor: $df Roll: $d_roll  Quotient: $dq Bonus: $defence_bonus ");

    my $damage = 0;

    if ( $aq > $dq ) {

        # Attack hits
        $damage = ( int rand $attacker->damage ) + 1;

        $defender->hit($damage);

        # Record damage in combat log
        my $damage_col = $attacker->is_character ? 'total_character_damage' : 'total_creature_damage';
        $c->stash->{combat_log}->set_column( $damage_col, $c->stash->{combat_log}->get_column($damage_col) + $damage );

        if ( $defender->is_dead ) {
            my $death_col = $defender->is_character ? 'character_deaths' : 'creature_deaths';
            $c->stash->{combat_log}->set_column( $death_col, $c->stash->{combat_log}->get_column($death_col) + 1 );

            if ( $defender->is_character ) {
                $c->model('DBIC::Character_History')->create(
                    {
                        character_id => $defender->id,
                        day_id       => $c->stash->{today}->id,
                        event        => $defender->character_name . " was slain by a " . $attacker->type->creature_type,
                    },
                );
            }
        }

        $c->log->debug("Damage: $damage");
    }

    return $damage;
}

sub flee : Local {
    my ( $self, $c ) = @_;

    my $party = $c->stash->{party};

    return unless $party->in_combat_with;

    my $flee_successful = $c->forward('roll_flee_attempt');

    if ( $flee_successful ) {
        my $land = $c->forward('get_sector_to_flee_to');

        $party->land_id( $land->id );
        $party->in_combat_with(undef);

        # Still costs them turns to move (but they can do it even if they don't have enough turns left)
        $party->turns( $c->stash->{party}->turns - $land->movement_cost( $party->movement_factor ) );
        $party->turns(0) if $party->turns < 0;

        $party->update;

        # Refresh stash
        $c->stash->{party}          = $party;
        $c->stash->{party_location} = $land;

        $c->stash->{messages} = "You got away!";

        $c->stash->{combat_log}->outcome('party_fled');
        $c->stash->{combat_log}->encounter_ended( DateTime->now() );

        $c->forward('end_of_combat_cleanup');

        $c->forward( '/panel/refresh', [ 'messages', 'map', 'party', 'party_status' ] );
    }
    else {
        push @{ $c->stash->{combat_messages} }, 'You were unable to flee.';
        $c->session->{unsuccessful_flee_attempts}++;
        $c->forward('/combat/fight');
    }
}

sub roll_flee_attempt : Private {
    my ( $self, $c ) = @_;    
    
    my $party = $c->stash->{party};
    
    my $creature_group =
        $c->model('DBIC::CreatureGroup')
        ->find( { creature_group_id => $party->in_combat_with, }, { prefetch => { 'creatures' => [ 'type', 'creature_effects' ] }, }, );

    my $level_difference = $creature_group->level - $party->level;
    my $flee_chance =
        $c->config->{base_flee_chance} + ( $c->config->{flee_chance_level_modifier} * ( $level_difference > 0 ? $level_difference : 0 ) );

    $flee_chance += ( $c->config->{flee_chance_attempt_modifier} * $c->session->{unsuccessful_flee_attempts} );

    my $rand = Games::Dice::Advanced->roll("1d100");

    $c->log->debug("Flee roll: $rand");
    $c->log->debug( "Flee chance: " . $flee_chance );    
    
    return $rand < $flee_chance;    
}

sub creatures_flee : Private {
    my ( $self, $c ) = @_;

    my $land = $c->forward( 'get_sector_to_flee_to', [1] );

    $c->stash->{creature_group}->land_id( $land->id );
    $c->stash->{creature_group}->update;
    undef $c->stash->{creature_group};

    $c->stash->{party}->in_combat_with(undef);
    $c->stash->{party}->update;

    $c->stash->{messages} = "The creatures have fled!";

    $c->stash->{combat_log}->outcome('creatures_fled');
    $c->stash->{combat_log}->encounter_ended( DateTime->now() );

    $c->forward('end_of_combat_cleanup');

    $c->forward( '/panel/refresh', [ 'messages', 'party', 'party_status', 'map' ] );
}

# For the party or the creatures
sub get_sector_to_flee_to : Private {
    my ( $self, $c, $no_creatures_or_towns ) = @_;

    my $party_location = $c->stash->{party}->location;

    my @sectors_to_flee_to;
    my $range = 3;

    while ( !@sectors_to_flee_to ) {
        my ( $start_point, $end_point ) = RPG::Map->surrounds( $party_location->x, $party_location->y, $range, $range, );

        my %params;
        if ($no_creatures_or_towns) {
            $params{'creature_group.creature_group_id'} = undef;
            $params{'town.town_id'}                     = undef;
        }

        @sectors_to_flee_to = $c->model('DBIC::Land')->search(
            {
                %params,
                x => { '>=', $start_point->{x}, '<=', $end_point->{x}, '!=', $party_location->x },
                y => { '>=', $start_point->{y}, '<=', $end_point->{y}, '!=', $party_location->y },
            },
            { join => [ 'creature_group', 'town' ] },
        );

        $range++;
    }

    @sectors_to_flee_to = shuffle @sectors_to_flee_to;
    my $land = shift @sectors_to_flee_to;

    $c->log->debug( "Fleeing to " . $land->x . ", " . $land->y );

    return $land;
}

sub finish : Private {
    my ( $self, $c ) = @_;

    my @creatures = $c->stash->{creature_group}->creatures;

    my $xp;

    foreach my $creature (@creatures) {

        # Generate random modifier between 0.6 and 1.5
        my $rand = ( Games::Dice::Advanced->roll('1d10') / 10 ) + 0.5;
        $xp += int( $creature->type->level * $rand * RPG->config->{xp_multiplier} );
    }

    my $avg_creature_level = $c->stash->{creature_group}->level;

    my @characters = $c->stash->{party}->characters;

    my $awarded_xp = $c->forward( '/combat/distribute_xp', [ $xp, [ map { $_->is_dead ? () : $_->id } @characters ] ] );

    my $xp_messages = $c->forward( '/party/xp_gain', [$awarded_xp] );

    push @{ $c->stash->{combat_messages} }, @$xp_messages;

    my $gold = scalar(@creatures) * $avg_creature_level * Games::Dice::Advanced->roll('2d6');

    push @{ $c->stash->{combat_messages} }, "You find $gold gold";

    $c->forward( 'check_for_item_found', [ \@characters, $avg_creature_level ] );

    $c->stash->{party}->in_combat_with(undef);
    $c->stash->{party}->gold( $c->stash->{party}->gold + $gold );
    $c->stash->{party}->update;

    $c->stash->{combat_log}->gold_found($gold);
    $c->stash->{combat_log}->xp_awarded($xp);
    $c->stash->{combat_log}->encounter_ended( DateTime->now() );

    # Check for state of quests
    my $messages = $c->forward( '/quest/check_action', ['creature_group_killed'] );
    push @{ $c->stash->{combat_messages} }, @$messages;

    # Don't delete creature group, since it's needed by news
    $c->stash->{creature_group}->land_id(undef);
    $c->stash->{creature_group}->dungeon_grid_id(undef);
    $c->stash->{creature_group}->update;

    $c->stash->{party_location}->creature_threat( $c->stash->{party_location}->creature_threat - 5 );
    $c->stash->{party_location}->update;    

    $c->forward('end_of_combat_cleanup');
}

# Things that need to be done no matter how the combat ended
sub end_of_combat_cleanup : Private {
    my ( $self, $c ) = @_;

    undef $c->session->{combat_action_param};
    undef $c->session->{rounds_since_last_double_attack};
    undef $c->session->{attack_history};
    undef $c->session->{unsuccessful_flee_attempts};

    foreach my $character ( $c->stash->{party}->characters ) {

        # Remove character effects from this combat
        foreach my $effect ( $character->character_effects ) {
            $effect->delete if $effect->effect->combat;
        }

        # Remove last_combat_actions that can't be carried between combats
        #  (currently just 'cast')
        if ( $character->last_combat_action eq 'Cast' ) {
            $character->last_combat_action('Defend');
            $character->update;
        }
    }
    
    $c->stash->{refresh_panels} = ['map'];
}

sub check_for_item_found : Private {
    my ( $self, $c, $characters, $avg_creature_level ) = @_;

    # See if party find an item
    if ( Games::Dice::Advanced->roll('1d100') <= $avg_creature_level * $c->config->{chance_to_find_item} ) {
        my $max_prevalence = $avg_creature_level * $c->config->{prevalence_per_creature_level_to_find};

        # Get item_types within the prevalance roll
        my @item_types = shuffle $c->model('DBIC::Item_Type')->search(
            {
                prevalence        => { '<=', $max_prevalence },
                'category.hidden' => 0,
            },
            { join => 'category', },
        );

        my $item_type = shift @item_types;

        croak "Couldn't find item to give to party under prevalence $max_prevalence\n"
            unless $item_type;

        # Choose a random character to find it
        my $finder;
        while ( !$finder || $finder->is_dead ) {
            $finder = ( shuffle @$characters )[0];
        }

        # Create the item
        my $item = $c->model('DBIC::Items')->create( { item_type_id => $item_type->id, }, );

        $item->add_to_characters_inventory($finder);

        push @{ $c->stash->{combat_messages} }, $finder->character_name . " found a " . $item->display_name;
    }
}

sub distribute_xp : Private {
    my ( $self, $c, $xp, $char_ids ) = @_;

    #warn Dumper [$xp, $char_ids];

    my %awarded_xp;

    # Everyone gets 10% to start with
    my $min_xp = int $xp * 0.10;
    @awarded_xp{@$char_ids} = ($min_xp) x scalar @$char_ids;
    $xp -= $min_xp * scalar @$char_ids;

    # Work out total damage, and total attacks made
    my ( $total_damage, $total_attacks );
    map { $total_damage  += $_ } values %{ $c->session->{damage_done} };
    map { $total_attacks += $_ } values %{ $c->session->{attack_count} };

    #warn "total dam: $total_damage\n";
    #warn "total att: $total_attacks\n";

    # Assign each character XP points, up to a max of 30% of the pool
    # (note, they can actually get up to 35%, but we've already given them 5% above)
    # Damage done vs attacks recieved is weighted at 60/40
    my $total_awarded = 0;
    foreach my $char_id (@$char_ids) {
        my ( $damage_percent, $attacked_percent ) = ( 0, 0 );

        #warn $char_id;

        #warn "dam_done:  " . $c->session->{damage_done}{$char_id};
        #warn "att_count: " . $c->session->{attack_count}{$char_id};

        $damage_percent = ( ( $c->session->{damage_done}{$char_id} || 0 ) / $total_damage ) * 0.6
            if $total_damage > 0;
        $attacked_percent = ( ( $c->session->{attack_count}{$char_id} || 0 ) / $total_attacks ) * 0.4
            if $total_attacks > 0;

        #warn "dam: " . $damage_percent;
        #warn "att: " . $attacked_percent;

        my $total_percent = $damage_percent + $attacked_percent;
        $total_percent = 0.35 if $total_percent > 0.35;

        #warn $total_percent;

        my $xp_awarded = int $xp * $total_percent;

        #warn $xp_awarded;

        $awarded_xp{$char_id} += $xp_awarded;
        $total_awarded += $xp_awarded;
    }

    # Figure out how much is left, if any
    $xp -= $total_awarded;

    # If there's any XP left, divide it up amongst the party. We round down, so some could be lost
    if ( $xp > 0 ) {
        my $spare_xp = int( $xp / scalar @$char_ids );
        map { $awarded_xp{$_} += $spare_xp } keys %awarded_xp;
    }

    undef $c->session->{damage_done};
    undef $c->session->{attack_count};

    return \%awarded_xp;
}

# Check the effects at the end of the round, decrement the timer, and delete any that have expired
sub process_effects : Private {
    my ( $self, $c ) = @_;

    my @character_effects = $c->model('DBIC::Character_Effect')->search(
        {
            character_id    => [ map { $_->id } $c->stash->{party}->characters ],
            'effect.combat' => 1,
        },
        { prefetch => 'effect', },
    );

    my @creature_effects = $c->model('DBIC::Creature_Effect')->search(
        {
            creature_id     => [ map { $_->id } $c->stash->{creature_group}->creatures ],
            'effect.combat' => 1,
        },
        { prefetch => 'effect', },
    );

    foreach my $effect ( @character_effects, @creature_effects ) {
        $effect->effect->time_left( $effect->effect->time_left - 1 );

        if ( $effect->effect->time_left == 0 ) {
            $effect->effect->delete;
            $effect->delete;
        }
        else {
            $effect->effect->update;
        }
    }

    # Refresh party / creature_group in stash if necessary
    if (@creature_effects) {
        $c->stash->{creature_group} = $c->model('DBIC::CreatureGroup')->get_by_id( $c->stash->{creature_group}->id );
    }

    if (@character_effects) {
        $c->stash->{party} = $c->model('DBIC::Party')->get_by_player_id( $c->session->{player}->id );
    }
}

1;
