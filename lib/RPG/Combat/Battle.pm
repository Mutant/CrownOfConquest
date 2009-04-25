package RPG::Combat::Battle;

use Mouse::Role;

use List::Util qw(shuffle);
use Carp;
use Storable qw(freeze thaw);
use DateTime;

requires qw/combatants process_effects opponents_of opponents check_for_flee/;

has 'schema'             => ( is => 'ro', isa => 'RPG::Schema', required => 1 );
has 'combat_complete'    => ( is => 'rw', isa => 'Bool',        default  => 0 );
has 'config'             => ( is => 'ro', isa => 'HashRef',     required => 0 );

# Private
has 'session'           => ( is => 'ro', isa => 'HashRef',                 init_arg => undef, builder => '_build_session',           lazy => 1 );
has 'combat_log'        => ( is => 'ro', isa => 'RPG::Schema::Combat_Log', init_arg => undef, builder => '_build_combat_log',        lazy => 1 );
has 'combat_factors'    => ( is => 'ro', isa => 'HashRef',                 required => 0,     builder => '_build_combat_factors',    lazy => 1, );
has 'character_weapons' => ( is => 'ro', isa => 'HashRef',                 required => 0,     builder => '_build_character_weapons', lazy => 1, );

sub execute_round {
    my $self = shift;
    
    if ($self->check_for_flee) {
        # One opponent has fled, end of the battle
        # TODO: need to return something here?
        #$c->forward('end_of_combat_cleanup');

        #$c->forward( '/panel/refresh', [ 'messages', 'party', 'party_status', 'map' ] );
        
        return;
    }

    # Process magical effects
    $self->process_effects;

    my @combatants = $self->combatants;

    # Get list of combatants, modified for changes in attack frequency, and radomised in order
    @combatants = $self->get_combatant_list(@combatants);

    my @combat_messages;

    foreach my $combatant (@combatants) {
        next if $combatant->is_dead;

        my $action_result;
        if ( $combatant->is_character ) {
            $action_result = $self->character_action($combatant);
        }
        else {
            $action_result = $self->creature_action($combatant);
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

        # TODO: Need to return
        #  * number of attacks
        #  * damage done
        #  * deaths
        #  * whether armour / weapon was broken

        # TODO: not sure where this goes...

=comment        
        if ( $self->combat_complete || $c->stash->{party}->defunct ) {
            push @{ $c->stash->{refresh_panels} }, ' map ';
            last;
        }
=cut

    }

=comment
    push @{ $c->stash->{combat_messages} },
        $c->forward(
        ' RPG::V::TT ',
        [
            {
                template => ' combat / message . html ',
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

    

    
=cut

    $self->combat_log->rounds( $self->combat_log->rounds + 1 );

}

# TODO: needs a better name
sub _process_effects {
    my $self    = shift;
    my @effects = @_;

    foreach my $effect (@effects) {
        $effect->effect->time_left( $effect->effect->time_left - 1 );

        if ( $effect->effect->time_left == 0 ) {
            $effect->effect->delete;
            $effect->delete;
        }
        else {
            $effect->effect->update;
        }
    }
}

sub get_combatant_list {
    my $self       = shift;
    my @combatants = @_;

    my @sorted_combatants;

    foreach my $combatant (@combatants) {
        my @attack_history;

        my $type = $combatant->is_character ? 'character' : 'creature';

        @attack_history = @{ $self->session->{attack_history}{$type}{ $combatant->id } }
            if $self->session->{attack_history}{$type}{ $combatant->id };

        my $number_of_attacks = $combatant->number_of_attacks(@attack_history);

        push @attack_history, $number_of_attacks;

        $self->session->{attack_history}{$type}{ $combatant->id } = \@attack_history;

        for ( 1 .. $number_of_attacks ) {
            push @sorted_combatants, $combatant;
        }
    }

    @sorted_combatants = shuffle @sorted_combatants;

    return @sorted_combatants;
}

sub character_action {
    my ( $self, $character ) = @_;

    my ( $opponent, $damage );

    my $opp_group = $self->opponents_of($character);

    my %opponents = map { $_->id => $_ } $opp_group->members;

    if ( $character->last_combat_action eq 'Attack' ) {

        # If they' ve selected a target, make sure it's still alive
        my $targetted_opponent = $character->last_combat_param1;

        if ( $targetted_opponent && $opponents{$targetted_opponent} && !$opponents{$targetted_opponent}->is_dead ) {
            $opponent = $opponents{$targetted_opponent};
        }

        # If we don't have a target, choose one randomly
        unless ($opponent) {
            for my $id ( shuffle keys %opponents ) {
                unless ( $opponents{$id}->is_dead ) {
                    $opponent = $opponents{$id};
                    last;
                }
            }

            unless ($opponent) {

                # No living opponent found, something weird has happened
                croak "Couldn't find an opponent to attack!\n";
            }
        }

        $damage = $self->attack( $character, $opponent );

        # Store damage done for XP purposes
        $self->{damage_done}{ $character->id } = $damage unless ref $damage;

        # If creature is now dead, see if any other creatures are left alive.
        #  If not, combat is over.
        if ( $opponent->is_dead && $opp_group->number_alive == 0 ) {

            # We don't actually do any of the stuff to complete the combat here, so a
            #  later action can still display monsters, messages, etc.
            $self->combat_log->outcome('party_won');
            $self->combat_log->encounter_ended( DateTime->now() );

            $self->combat_complete(1);
        }

        return [ $opponent, $damage ];
    }
    elsif ( $character->last_combat_action eq 'Cast' ) {

        # TODO: spells would be nice

=comment
        my $message =
            $c->forward( '/magic/cast',
            [ $character, $c->session->{combat_action_param}{ $character->id }[0], $c->session->{combat_action_param}{ $character->id }[1], ],
            );

        # Since effects could have changed an af or df, we delete any id's in the cache matching the second param
        #  (the target's id) and then recompute.
        my $target = $c->session->{combat_action_param}{ $character->id }[1];

        $c->forward( 'refresh_factor_cache', [$target] );

        $character->last_combat_action('Defend');
        $character->update;

        $c->stash->{combat_log}->spells_cast( $c->stash->{combat_log}->spells_cast + 1 );

        # Check for all creatures dead
        if ( $creature_group->number_alive == 0 ) {
            $c->stash->{combat_log}->outcome('party_won');
            $c->stash->{combat_log}->encounter_ended( DateTime->now() );

            $c->stash->{combat_complete} = 1;
        }

        return $message;
=cut

    }
}

sub creature_action {
    my ( $self, $creature ) = @_;

    my $party = $self->opponents_of($creature);

    my @characters = sort { $a->party_order <=> $b->party_order } $party->characters;
    @characters = grep { !$_->is_dead } @characters;    # Get rid of corpses

    # Figure out whether creature will target front or back rank
    my $rank_pos = $party->rank_separator_position;

    $rank_pos = scalar @characters if $rank_pos > scalar @characters;

    unless ( $rank_pos == scalar @characters ) {
        my $rank_roll = Games::Dice::Advanced->roll('1d100');
        if ( $rank_roll <= $self->config->{front_rank_attack_chance} ) {

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
    foreach my $char_to_check ( shuffle @characters ) {
        unless ( $char_to_check->is_dead ) {
            $character = $char_to_check;
            last;
        }
    }

    unless ($character) {
        croak "Couldn't find a character to attack!\n";
    }

    # Count number of times attacked for XP purposes
    $self->session->{attack_count}{ $character->id }++;

    my $damage = $self->attack( $creature, $character );

    # Check for wiped out party
    if ( $character->is_dead && $party->number_alive == 0 ) {

        $self->combat_log->outcome('creatures_won');
        $self->combat_log->encounter_ended( DateTime->now() );

        $party->defunct( DateTime->now() );
        $party->update;

    }

    return [ $character, $damage ];
}

sub attack {
    my $self = shift;
    my ( $attacker, $defender ) = @_;

    my $attacker_type = $attacker->is_character ? 'character' : 'creature';

    #$c->log->debug("About to check attack");

    if ( $attacker_type eq 'character' ) {
        my $attack_error = $self->check_character_attack($attacker);

        #$c->log->debug( "Got attack error: " . Dumper $attack_error);
        return $attack_error if $attack_error;
    }

    my $defending = 0;
    if ( $defender->is_character && $defender->last_combat_action eq 'Defend' ) {
        $defending = 1;
    }

    #$c->log->debug("About to execute defence");

    if ( my $defence_message = $defender->execute_defence ) {
        if ( $defence_message->{armour_broken} ) {

            # TODO: figure out how to deal with this
            # Armour has broken, clear out this character's factor cache
            #$c->forward( 'refresh_factor_cache', [ $defender->id ] );
        }
    }

    my $a_roll = Games::Dice::Advanced->roll( '1d' . $self->config->{attack_dice_roll} );
    my $d_roll = Games::Dice::Advanced->roll( '1d' . $self->config->{defence_dice_roll} );

    my $defence_bonus = $defending ? $self->config->{defend_bonus} : 0;

    my $af = $self->combat_factors->{ $attacker->is_character ? 'character' : 'creature' }{ $attacker->id }{af};
    my $df = $self->combat_factors->{ $defender->is_character ? 'character' : 'creature' }{ $defender->id }{df};

    my $aq = $af - $a_roll;
    my $dq = $df + $defence_bonus - $d_roll;

    #$c->log->debug( "Executing attack. Attacker: " . $attacker->name . ", Defender: " . $defender->name );

    #$c->log->debug("Attack:  Factor: $af Roll: $a_roll  Quotient: $aq");
    #$c->log->debug("Defence: Factor: $df Roll: $d_roll  Quotient: $dq Bonus: $defence_bonus ");

    my $damage = 0;

    if ( $aq > $dq ) {

        # Attack hits
        my $dam_max = $self->combat_factors->{ $attacker->is_character ? 'character' : 'creature' }{ $attacker->id }{dam};
        $damage = Games::Dice::Advanced->roll( '1d' . $dam_max )
            unless $dam_max <= 0;

        $defender->hit($damage);

        # Record damage in combat log
        my $damage_col = $attacker->is_character ? 'total_character_damage' : 'total_creature_damage';
        $self->combat_log->set_column( $damage_col, ($self->combat_log->get_column($damage_col) || 0) + $damage );

        if ( $defender->is_dead ) {

            my $death_col = $defender->is_character ? 'character_deaths' : 'creature_deaths';
            $self->combat_log->set_column( $death_col, ($self->combat_log->get_column($death_col) || 0) + 1 );

            if ( $defender->is_character ) {
                $self->schema('Character_History')->create(
                    {
                        character_id => $defender->id,
                        day_id       => $self->schema->resultset('Day')->find_today->id,
                        event        => $defender->character_name . " was slain by a " . $attacker->type->creature_type,
                    },
                );
            }
        }

        #$c->log->debug("Damage: $damage");
    }

    return $damage;
}

sub check_character_attack {
    my ( $self, $attacker ) = @_;

    my $weapon_durability = $self->character_weapons->{ $attacker->id }{durability};

    return { weapon_broken => 1 } if $weapon_durability == 0;

    my $weapon_damage_roll = Games::Dice::Advanced->roll('1d3');

    if ( $weapon_damage_roll == 1 ) {

        #$c->log->debug('Reducing durability of weapon');
        $weapon_durability--;

        my $var = $self->schema->resultset('Item_Variable')->find(
            {
                item_id                                 => $self->character_weapons->{ $attacker->id }{id},
                'item_variable_name.item_variable_name' => 'Durability',
            },
            { join => 'item_variable_name', }
        );

        if ($var) {
            $var->update( { item_variable_value => $weapon_durability, } );
            $self->character_weapons->{ $attacker->id }{durability} = $weapon_durability;
        }
    }

    if ( $weapon_durability <= 0 ) {

        # TODO: clear factor cache?
        #push @{ $c->stash->{refresh_panels} }, 'party';
        return { weapon_broken => 1 };
    }

    if ( ref $self->character_weapons->{ $attacker->id }{ammunition} eq 'ARRAY' ) {

        #$c->log->debug('Checking for ammo');
        my $ammo_found = 0;
        foreach my $ammo ( @{ $self->character_weapons->{ $attacker->id }{ammunition} } ) {
            next unless $ammo;
            if ( $ammo->{quantity} == 0 ) {
                $self->schema->resultset('Items')->find( { item_id => $ammo->{id}, }, )->delete;
                $ammo = undef;
                next;
            }

            $ammo->{quantity}--;
            $self->schema->resultset('Item_Variable')->find(
                {
                    item_id                                 => $ammo->{id},
                    'item_variable_name.item_variable_name' => 'Quantity',
                },
                { join => 'item_variable_name', }
            )->update( { item_variable_value => $ammo->{quantity}, } );

            $ammo_found = 1;
            last;
        }

        if ( !$ammo_found ) {
            return { no_ammo => 1 };
        }
    }

    return;
}



sub _build_session {
    my $self = shift;

    return {} unless $self->combat_log->session;

    return thaw $self->combat_log->session;
}

sub _build_combat_log {
    my $self = shift;

    my ( $opp1, $opp2 ) = $self->opponents;

    my $combat_log = $self->schema->resultset('Combat_Log')->find(
        {
            opponent_1_id   => $opp1->id,
            opponent_2_id   => $opp2->id,
            encounter_ended => undef,
        },
    );

    if ( !$combat_log ) {

        # TODO: fill in the blanks
        $combat_log = $self->schema->resultset('Combat_Log')->create(
            {
                opponent_1_id => $opp1->id,
                opponent_2_id => $opp2->id,

                #land_id              => $c->stash->{party_location}->id,
                encounter_started => DateTime->now(),

                #combat_initiated_by  => $initiated_by,
                #party_level          => $c->stash->{party}->level,
                #creature_group_level => $creature_group->level,
                #game_day             => $current_day,
            },
        );
    }

    return $combat_log;
}

sub _build_combat_factors {
    my $self = shift;

    my %combat_factors;

    return $self->session->{combat_factors} if defined $self->session->{combat_factors};

    foreach my $combatant ( $self->combatants ) {
        next if $combatant->is_dead;

        my $type = $combatant->is_character ? 'character' : 'creature';

        $combat_factors{$type}{ $combatant->id }{af}  = $combatant->attack_factor;
        $combat_factors{$type}{ $combatant->id }{df}  = $combatant->defence_factor;
        $combat_factors{$type}{ $combatant->id }{dam} = $combatant->damage;

    }

    $self->session->{combat_factors} = \%combat_factors;

    return \%combat_factors;
}

sub _build_character_weapons {
    my $self = shift;

    my %character_weapons;

    return $self->session->{character_weapons} if defined $self->session->{character_weapons};

    foreach my $combatant ( $self->combatants ) {
        next unless $combatant->is_character;

        my ($weapon) = $combatant->get_equipped_item('Weapon');

        if ($weapon) {
            $character_weapons{ $combatant->id }{id}         = $weapon->id;
            $character_weapons{ $combatant->id }{durability} = $weapon->variable('Durability');
            $character_weapons{ $combatant->id }{ammunition} = $combatant->ammunition_for_item($weapon);
        }
    }

    $self->session->{character_weapons} = \%character_weapons;

    return \%character_weapons;
}

sub DEMOLISH {
    my $self = shift;

    if ( $self->session ) {
        my $session = freeze $self->session;

        $self->combat_log->session($session);
    }

    $self->combat_log->update;
}

1;
