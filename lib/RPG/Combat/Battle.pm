package RPG::Combat::Battle;

use Moose::Role;

use List::Util qw(shuffle);
use Carp;
use Storable qw(freeze thaw);
use DateTime;
use Data::Dumper;

requires qw/combatants process_effects opponents_of opponents check_for_flee party_flees_to roll_flee_attempt/;

has 'schema'              => ( is => 'ro', isa => 'RPG::Schema', required => 1 );
has 'config'              => ( is => 'ro', isa => 'HashRef',     required => 0 );
has 'log'                 => ( is => 'ro', isa => 'Object',      required => 1 );
has 'creatures_initiated' => ( is => 'ro', isa => 'Bool',        default  => 0 );

# Private
has 'session'           => ( is => 'ro', isa => 'HashRef',                 init_arg => undef, builder => '_build_session',           lazy => 1 );
has 'combat_log'        => ( is => 'ro', isa => 'RPG::Schema::Combat_Log', init_arg => undef, builder => '_build_combat_log',        lazy => 1 );
has 'combat_factors'    => ( is => 'rw', isa => 'HashRef',                 required => 0,     builder => '_build_combat_factors',    lazy => 1, );
has 'character_weapons' => ( is => 'ro', isa => 'HashRef',                 required => 0,     builder => '_build_character_weapons', lazy => 1, );
has 'result' => ( is => 'ro', isa => 'HashRef', init_arg => undef, default => sub { {} } );

sub execute_round {
    my $self = shift;

    # TODO: return this by updating result attr instead
    if ( my $result = $self->check_for_flee ) {

        # One opponent has fled, end of the battle
        $self->end_of_combat_cleanup;

        return $result;
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

            # TODO: might be nice to clean up the way action results are returned
            if ( ref $action_result eq 'ARRAY' ) {
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

        if ( $self->check_for_end_of_combat($combatant) ) {
            $self->finish;
            $self->end_of_combat_cleanup;
            last;
        }
    }

    $self->party->turns( $self->party->turns - 1 );
    $self->party->update;

    $self->combat_log->rounds( ( $self->combat_log->rounds || 0 ) + 1 );

    $self->result->{messages} = \@combat_messages;

    return $self->result;
}

sub check_for_end_of_combat {
    my $self           = shift;
    my $last_combatant = shift;

    my $opponents = $self->opponents_of($last_combatant);
    if ( $opponents->number_alive == 0 ) {
        my $oppponent1 = ( $self->opponents )[0];
        my $opp = $opponents->id == $oppponent1->id && $opponents->isa( $oppponent1->meta->name ) ? 'opp2' : 'opp1';
        $self->combat_log->outcome( $opp . "_won" );
        $self->combat_log->encounter_ended( DateTime->now() );
        $self->result->{combat_complete} = 1;

        # TODO: best way to find if opponents are a party?
        if ( $opponents->isa('RPG::Schema::Party') ) {
            $opponents->defunct( DateTime->now() );
            $opponents->update;
        }

        return 1;
    }

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
        $self->session->{damage_done}{ $character->id } = $damage unless ref $damage;

        return [ $opponent, $damage ];
    }
    elsif ( $character->last_combat_action eq 'Cast' ) {
        my $spell = $self->schema->resultset('Spell')->find( $character->last_combat_param1 );

        my $result = $spell->cast( $character, $character->last_combat_param2 );

        # Since effects could have changed an af or df, we delete any id's in the cache matching the second param
        #  (the target's id) and then recompute.
        $self->refresh_factor_cache( $character->last_combat_param2 );

        $character->last_combat_action('Defend');
        $character->update;

        $self->combat_log->spells_cast( $self->combat_log->spells_cast + 1 );

        return $result;

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

    return [ $character, $damage ];
}

sub attack {
    my $self = shift;
    my ( $attacker, $defender ) = @_;

    my $attacker_type = $attacker->is_character ? 'character' : 'creature';

    $self->log->debug("About to check attack");

    if ( $attacker_type eq 'character' ) {
        my $attack_error = $self->check_character_attack($attacker);

        $self->log->debug( "Got attack error: " . Dumper $attack_error);
        return $attack_error if $attack_error;
    }

    my $defending = 0;
    if ( $defender->is_character && $defender->last_combat_action eq 'Defend' ) {
        $defending = 1;
    }

    $self->log->debug("About to execute defence");

    if ( my $defence_message = $defender->execute_defence ) {
        if ( $defence_message->{armour_broken} ) {

            # Armour has broken, clear out this character's factor cache
            $self->refresh_factor_cache( $attacker->id );
        }
    }

    my $a_roll = Games::Dice::Advanced->roll( '1d' . $self->config->{attack_dice_roll} );
    my $d_roll = Games::Dice::Advanced->roll( '1d' . $self->config->{defence_dice_roll} );

    my $defence_bonus = $defending ? $self->config->{defend_bonus} : 0;

    my $af = $self->combat_factors->{ $attacker->is_character ? 'character' : 'creature' }{ $attacker->id }{af};
    my $df = $self->combat_factors->{ $defender->is_character ? 'character' : 'creature' }{ $defender->id }{df};

    my $aq = $af - $a_roll;
    my $dq = $df + $defence_bonus - $d_roll;

    $self->log->debug( "Executing attack. Attacker: " . $attacker->name . ", Defender: " . $defender->name );

    $self->log->debug("Attack:  Factor: $af Roll: $a_roll  Quotient: $aq");
    $self->log->debug("Defence: Factor: $df Roll: $d_roll  Quotient: $dq Bonus: $defence_bonus ");

    my $damage = 0;

    if ( $aq > $dq ) {

        # Attack hits
        my $dam_max = $self->combat_factors->{ $attacker->is_character ? 'character' : 'creature' }{ $attacker->id }{dam};
        $damage = Games::Dice::Advanced->roll( '1d' . $dam_max )
            unless $dam_max <= 0;

        $defender->hit($damage);

        # Record damage in combat log
        my $damage_col = $attacker->is_character ? 'total_character_damage' : 'total_creature_damage';
        $self->combat_log->set_column( $damage_col, ( $self->combat_log->get_column($damage_col) || 0 ) + $damage );

        if ( $defender->is_dead ) {

            my $death_col = $defender->is_character ? 'character_deaths' : 'creature_deaths';
            $self->combat_log->set_column( $death_col, ( $self->combat_log->get_column($death_col) || 0 ) + 1 );

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

        $self->log->debug("Damage: $damage");
    }

    return $damage;
}

sub check_character_attack {
    my ( $self, $attacker ) = @_;

    my $weapon_durability = $self->character_weapons->{ $attacker->id }{durability} || 0;

    return { weapon_broken => 1 } if $weapon_durability == 0;

    my $weapon_damage_roll = Games::Dice::Advanced->roll('1d3');

    if ( $weapon_damage_roll == 1 ) {

        $self->log->debug('Reducing durability of weapon');
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

        # TODO: need to refresh party list
        #push @{ $c->stash->{refresh_panels} }, 'party';
        return { weapon_broken => 1 };
    }

    if ( ref $self->character_weapons->{ $attacker->id }{ammunition} eq 'ARRAY' ) {

        $self->log->debug('Checking for ammo');
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

sub party_flee {
    my $self = shift;

    $self->combat_log->flee_attempts( ( $self->combat_log->flee_attempts || 0 ) + 1 );

    my $flee_successful = $self->roll_flee_attempt;

    if ($flee_successful) {
        my $land = $self->get_sector_to_flee_to;

        $self->party_flees_to($land);

        $self->party->update;

        $self->combat_log->outcome('opp1_fled');
        $self->combat_log->encounter_ended( DateTime->now() );

        return 1;
    }
    else {
        $self->session->{unsuccessful_flee_attempts}++;

        return 0;
    }
}

sub end_of_combat_cleanup {
    my $self = shift;

    foreach my $character ( $self->party->characters ) {

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
}

sub finish {
    my $self = shift;

    my @creatures = $self->creature_group->creatures;

    my $xp;

    foreach my $creature (@creatures) {

        # Generate random modifier between 0.6 and 1.5
        my $rand = ( Games::Dice::Advanced->roll('1d10') / 10 ) + 0.5;
        $xp += int( $creature->type->level * $rand * $self->config->{xp_multiplier} );
    }

    my $avg_creature_level = $self->creature_group->level;

    my @characters = $self->party->characters;

    $self->result->{awarded_xp} = $self->distribute_xp( $xp, [ map { $_->is_dead ? () : $_->id } @characters ] );

    my $gold = scalar(@creatures) * $avg_creature_level * Games::Dice::Advanced->roll('2d6');
    $self->result->{gold} = $gold;

    $self->check_for_item_found( \@characters, $avg_creature_level );

    $self->party->in_combat_with(undef);
    $self->party->gold( $self->party->gold + $gold );
    $self->party->update;

    $self->combat_log->gold_found($gold);
    $self->combat_log->xp_awarded($xp);
    $self->combat_log->encounter_ended( DateTime->now() );

    # Don't delete creature group, since it's needed by news
    $self->creature_group->land_id(undef);
    $self->creature_group->dungeon_grid_id(undef);
    $self->creature_group->update;

    # TODO: nasty
    if ( $self->location->isa('RPG::Schema::Land') ) {
        $self->location->creature_threat( $self->location->creature_threat - 5 );
        $self->location->update;
    }

    $self->end_of_combat_cleanup;
}

sub check_for_item_found {
    my $self = shift;
    my ( $characters, $avg_creature_level ) = @_;

    # See if party find an item
    if ( Games::Dice::Advanced->roll('1d100') <= $avg_creature_level * $self->config->{chance_to_find_item} ) {
        my $max_prevalence = $avg_creature_level * $self->config->{prevalence_per_creature_level_to_find};

        # Get item_types within the prevalance roll
        my @item_types = shuffle $self->schema->resultset('Item_Type')->search(
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
        foreach my $character ( shuffle @$characters ) {
            unless ( $character->is_dead ) {
                $finder = $character;
                last;
            }
        }

        # Create the item
        my $item = $self->schema->resultset('Items')->create( { item_type_id => $item_type->id, }, );

        $item->add_to_characters_inventory($finder);

        $self->result->{found_items} = [
            {
                finder => $finder,
                item   => $item,
            }
        ];
    }
}

sub distribute_xp {
    my ( $self, $xp, $char_ids ) = @_;

    my %awarded_xp;

    # Everyone gets 10% to start with
    my $min_xp = int $xp * 0.10;
    @awarded_xp{@$char_ids} = ($min_xp) x scalar @$char_ids;
    $xp -= $min_xp * scalar @$char_ids;

    # Work out total damage, and total attacks made
    my ( $total_damage, $total_attacks ) = ( 0, 0 );
    map { $total_damage  += $_ } values %{ $self->session->{damage_done} };
    map { $total_attacks += $_ } values %{ $self->session->{attack_count} };

    # Assign each character XP points, up to a max of 30% of the pool
    # (note, they can actually get up to 35%, but we've already given them 5% above)
    # Damage done vs attacks recieved is weighted at 60/40
    my $total_awarded = 0;
    foreach my $char_id (@$char_ids) {
        my ( $damage_percent, $attacked_percent ) = ( 0, 0 );

        $damage_percent = ( ( $self->session->{damage_done}{$char_id} || 0 ) / $total_damage ) * 0.6
            if $total_damage > 0;
        $attacked_percent = ( ( $self->session->{attack_count}{$char_id} || 0 ) / $total_attacks ) * 0.4
            if $total_attacks > 0;

        my $total_percent = $damage_percent + $attacked_percent;
        $total_percent = 0.35 if $total_percent > 0.35;

        my $xp_awarded = int $xp * $total_percent;

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

    return \%awarded_xp;
}

sub _build_session {
    my $self = shift;

    return {} unless $self->combat_log->session;

    return thaw $self->combat_log->session;
}

sub _build_combat_log {
    my $self = shift;

    my ( $opp1, $opp2 ) = $self->opponents;

    my $opp1_type = $opp1->isa('RPG::Schema::Party') ? 'party' : 'creature_group';
    my $opp2_type = $opp2->isa('RPG::Schema::Party') ? 'party' : 'creature_group';

    my $combat_log = $self->schema->resultset('Combat_Log')->find(
        {
            opponent_1_id   => $opp1->id,
            opponent_1_type => $opp1_type,
            opponent_2_id   => $opp2->id,
            opponent_2_type => $opp2_type,
            encounter_ended => undef,
        },
    );

    if ( !$combat_log ) {
        $combat_log = $self->schema->resultset('Combat_Log')->create(
            {
                opponent_1_id        => $opp1->id,
                opponent_1_type      => $opp1_type,
                opponent_2_id        => $opp2->id,
                opponent_2_type      => $opp2_type,
                land_id              => $self->location->id,
                encounter_started    => DateTime->now(),
                combat_initiated_by  => $self->creatures_initiated ? 'opp2' : 'opp1',
                party_level          => $self->party->level,
                creature_group_level => $self->creature_group->level,
                game_day             => $self->schema->resultset('Day')->find_today->id,
                spells_cast          => 0,
            },
        );
    }

    return $combat_log;
}

# Refresh a combatant's details in the factor cache
# Note, we're only passed in a combatant id, which could be a creature or character. It's possible that we could have
#  a creature *and* a character with the same id. If that happens, we'll just end up refreshing both of them in the cache. Oh well.
# We only have the id as this is all we have when casting a spell, and we don't know whether it's a creature or character
sub refresh_factor_cache {
    my ( $self, $combatant_id_to_refresh ) = @_;

    my @cached_combatant_ids = ( keys %{ $self->session->{combat_factors}{character} }, keys %{ $self->session->{combat_factors}{creature} }, );

    $self->log->debug("Deleting combat factor cache for target id $combatant_id_to_refresh");

    foreach my $combatant_id (@cached_combatant_ids) {
        delete $self->session->{combat_factors}{character}{$combatant_id}
            if $combatant_id == $combatant_id_to_refresh;
        delete $self->session->{combat_factors}{creature}{$combatant_id}
            if $combatant_id == $combatant_id_to_refresh;
    }

    $self->combat_factors( $self->_build_combat_factors );
}

sub _build_combat_factors {
    my $self = shift;

    my %combat_factors;

    %combat_factors = %{ $self->session->{combat_factors} } if defined $self->session->{combat_factors};

    foreach my $combatant ( $self->combatants ) {
        next if $combatant->is_dead;

        my $type = $combatant->is_character ? 'character' : 'creature';

        next if defined $combat_factors{$type}{ $combatant->id };

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
