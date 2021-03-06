package RPG::Combat::Battle;

use Moose::Role;

use List::Util qw(shuffle);
use Carp;
use Storable qw(freeze thaw);
use DateTime;
use Data::Dumper;
use Math::Round qw(round);
use Try::Tiny;

use RPG::Combat::ActionResult;
use RPG::Combat::MessageDisplayer;
use RPG::Combat::EffectResult;

use RPG::Combat::MagicalDamage::Fire;
use RPG::Combat::MagicalDamage::Ice;
use RPG::Combat::MagicalDamage::Poison;

requires qw/process_effects opponents_of opponents check_for_flee finish opponent_of_by_id initiated_by is_online/;

has 'schema' => ( is => 'ro', isa => 'RPG::Schema', required => 1 );
has 'config' => ( is => 'ro', isa => 'HashRef',     required => 0 );
has 'log'    => ( is => 'ro', isa => 'Object',      required => 1 );

# Private
has 'session' => ( is => 'ro', isa => 'HashRef', init_arg => undef, builder => '_build_session', lazy => 1 );
has 'combat_log' => ( is => 'ro', isa => 'RPG::Schema::Combat_Log', init_arg => undef, builder => '_build_combat_log', lazy => 1 );
has 'combat_factors' => ( is => 'rw', isa => 'HashRef', required => 0, builder => '_build_combat_factors', lazy => 1, );
has 'character_weapons' => ( is => 'ro', isa => 'HashRef', required => 0, builder => '_build_character_weapons', lazy => 1, );
has 'combatants_by_id' => ( is => 'ro', isa => 'HashRef', init_arg => undef, builder => '_build_combatants_by_id', lazy => 1, );
has 'combatants_alive' => ( is => 'ro', isa => 'HashRef', init_arg => undef, builder => '_build_combatants_alive', lazy => 1, );
has 'result' => ( is => 'ro', isa => 'HashRef', init_arg => undef, default => sub { {} } );

sub opponent_number_of_being {
    my $self  = shift;
    my $being = shift;

    return $self->opponent_number_of_group( $being->group );
}

sub opponent_number_of_group {
    my $self  = shift;
    my $group = shift;

    my ($opp1) = ( $self->opponents )[0];

    if ( $group->id == $opp1->id && $group->group_type eq $opp1->group_type ) {
        return 1;
    }
    else {
        return 2;
    }
}

sub opponents_of {
    my $self  = shift;
    my $being = shift;

    my @opponents = $self->opponents;

    if ( $opponents[0]->has_being($being) ) {
        return $opponents[1];
    }
    else {
        return $opponents[0];
    }
}

# Return a list of combatants on the opposing side of the being passed
#  Get lists from combatants(), ensuring the same references are used
sub opposing_combatants_of {
    my $self  = shift;
    my $being = shift;

    my @combatants = grep { $_->group_id != $being->group_id } $self->combatants;

    return @combatants;
}

# Returns true if the group initiated combat
sub group_initiated {
    my $self  = shift;
    my $group = shift;

    my $opp_number = $self->opponent_number_of_group($group);

    my $initiated_by = $self->initiated_by;

    return $initiated_by eq 'opp' . $opp_number ? 1 : 0;
}

# TODO: logic really needs a tidy up
sub execute_round {
    my $self = shift;

    # Clear any messages from the last round
    $self->result->{messages} = undef;

    my @combat_messages;

    # Check if encounter marked as ended
    if ( $self->combat_log->encounter_ended ) {
        $self->log->debug( "Combat marked as complete (as at " . $self->combat_log->encounter_ended . "), not executing round" );

        $self->result->{combat_complete} = 1;

        return;
    }

    eval {
        # Check for stalemates, fleeing or no one alive in one of the groups
        #  The latter should be caught from the end of the previous round, but we also check it here to be defensive
        my $dead_group = $self->check_for_end_of_combat;
        if ( $dead_group || $self->stalemate_check || $self->check_for_flee ) {

            # One opponent has fled, end of the battle
            $self->end_of_combat_cleanup;

            $self->result->{combat_complete} = 1;

            return;
        }

        # Process magical effects
        $self->process_effects;

        return if $self->result->{combat_complete};

        my @combatants = $self->combatants;

        # Get list of combatants, modified for changes in attack frequency, and randomised in order
        @combatants = $self->get_combatant_list(@combatants);

        push @combat_messages, $self->check_skills;

        $self->check_for_end_of_combat;

        return if $self->result->{combat_complete};

        foreach my $combatant (@combatants) {

            # TODO: following line can probably be removed
            #  Left here just in case there are cases where other instances of combatant data are written to
            $combatant->discard_changes;
            next if $combatant->is_dead;

            my $action_result;
            if ( $combatant->is_character ) {
                $self->log->debug("Executing character action");

                $action_result = $self->character_action($combatant);

                if ($action_result) {
                    $self->session->{damage_done}{ $combatant->id } += $action_result->damage || 0;
                }
            }
            else {
                $self->log->debug("Executing creature action");
                $action_result = $self->creature_action($combatant);
            }

            if ($action_result) {
                push @combat_messages, $action_result;

                $self->combat_log->record_damage( $self->opponent_number_of_being( $action_result->attacker ), $action_result->damage );

                my @defenders_killed;
                @defenders_killed = ( $action_result->defender ) if $action_result->defender_killed;
                if ( $action_result->magical_damage and my $other_damages = $action_result->magical_damage->other_damages ) {
                    foreach my $other_action_result (@$other_damages) {
                        push @defenders_killed, $other_action_result->defender if $other_action_result->defender_killed;
                        $self->combat_log->record_damage( $self->opponent_number_of_being( $action_result->attacker ), $other_action_result->damage );
                    }
                }

                foreach my $defender (@defenders_killed) {
                    my $opp_number_of_killed_combatant = $self->opponent_number_of_being($defender);
                    $self->combat_log->record_death($opp_number_of_killed_combatant);
                    $self->combatants_alive->{$opp_number_of_killed_combatant}--;

                    my $type = $defender->is_character ? 'character' : 'creature';
                    push @{ $self->session->{killed}{$type} }, $defender->id;
                }

                if ( my $losers = $self->check_for_end_of_combat ) {
                    last;
                }
            }

        }
    };
    if ($@) {
        die $@;
    }

    $self->combat_log->increment_rounds;

    push @{ $self->result->{messages} }, @combat_messages;

    $self->record_messages;

    undef $self->{_auto_cast_checked_for};
    undef $self->{_cast_this_round};

    return $self->result;
}

# If both sides are offline, check if any damage has been done in the last 10 rounds (on either side)
#  If no damage has been done, declare a 'stalemate'. This prevents battles lasting forever
sub stalemate_check {
    my $self = shift;

    return 0 if $self->is_online;

    return 0 if !defined $self->combat_log->rounds || $self->combat_log->rounds == 0 || $self->combat_log->rounds % 10 != 0;

    if ( $self->session->{stalemate_check} != 0 ) {

        # Damage done, so no stalemate
        $self->session->{stalemate_check} = 0;
        return 0;
    }
    else {

        # It's a stalemate
        $self->result->{stalemate} = 1;
        return 1;
    }
}

sub check_for_end_of_combat {
    my $self = shift;

    my $opp_num = 1;
    foreach my $opponents ( $self->opponents ) {
        if ( $self->combatants_alive->{$opp_num} <= 0 ) {
            my $opp = 'opp' . ( $self->opponent_number_of_group($opponents) == 1 ? 2 : 1 );

            #$self->log->debug("Combat over, opp #$opp won");

            $self->combat_log->outcome( $opp . "_won" );
            $self->combat_log->encounter_ended( DateTime->now() );

            $self->result->{combat_complete} = 1;

            # TODO: should be in a role?
            if ( $opponents->group_type eq 'party' ) {
                $opponents->wiped_out;
            }

            $self->result->{losers} = $opponents;
            $self->finish($opponents);
            $self->end_of_combat_cleanup;

            return $opponents;
        }
        $opp_num++;
    }
}

# TODO: needs a better name
sub _process_effects {
    my $self    = shift;
    my @effects = @_;

    foreach my $effect (@effects) {
        my $being;
        if ( $effect->can('character_id') ) {
            $being = $self->combatants_by_id->{character}{ $effect->character_id };
        }
        else {
            $being = $self->combatants_by_id->{creature}{ $effect->creature_id };
        }

        if ( !$being->is_dead && $effect->effect->modified_stat eq 'poison' ) {
            my $damage = Games::Dice::Advanced->roll( '1d' . $effect->effect->modifier );

            $being->hit( $damage, $self->opponents_of($being), 'poison' );

            my $result = RPG::Combat::EffectResult->new(
                defender => $being,
                damage   => $damage,
                effect   => 'poison',
            );

            push @{ $self->result->{messages} }, $result;

            if ( $being->is_dead ) {
                $self->combatants_alive->{ $self->opponent_number_of_being($being) }--;
            }

            if ( $self->check_for_end_of_combat ) {
                return;
            }
        }

        $effect->effect->time_left( $effect->effect->time_left - 1 );

        if ( $effect->effect->time_left <= 0 ) {
            $effect->effect->delete;
            $effect->delete;

            # Reload the combatant who has this effect, to make sure it's now gone
            $being->discard_changes;

        }
        else {
            $effect->effect->update;
        }
    }
}

# Record combat messages in the DB
sub record_messages {
    my $self = shift;

    my @opponents = $self->opponents;
    my %display_messages;

    foreach my $opp_number ( 1 .. 2 ) {
        my $group = $opponents[ $opp_number - 1 ];

        next if $group->group_type eq 'creature_group' && !$group->has_mayor;

        $self->log->debug("Generating combat messages");

        my @messages = RPG::Combat::MessageDisplayer->display(
            config   => $self->config,
            group    => $group,
            opponent => $opponents[ $opp_number == 1 ? 1 : 0 ],
            result   => $self->result,
            weapons  => $self->character_weapons,
        );

        $self->log->debug("Done generating combat messages");

        $self->schema->resultset('Combat_Log_Messages')->create(
            {
                combat_log_id   => $self->combat_log->id,
                round           => $self->combat_log->rounds,
                opponent_number => $opp_number,
                message         => join "", @messages,
            },
        );

        $display_messages{$opp_number} = \@messages;
    }

    $self->result->{display_messages} = \%display_messages;
}

sub get_combatant_list {
    my $self       = shift;
    my @combatants = @_;

    my @sorted_combatants;

    foreach my $combatant (@combatants) {

        my @attack_history;

        my $type = $combatant->is_character ? 'character' : 'creature';

        my $number_of_attacks = 1;
        @attack_history = @{ $self->session->{attack_history}{$type}{ $combatant->id } }
          if $self->session->{attack_history}{$type}{ $combatant->id };

        if ( $type ne 'character' || $combatant->last_combat_action ne 'Cast' ) {
            my $is_ranged = $type eq 'character' ?
              $self->character_weapons->{ $combatant->id }{is_ranged} :
              undef;

            $number_of_attacks = $combatant->number_of_attacks( $is_ranged, @attack_history );
        }

        push @attack_history, $number_of_attacks;

        $self->session->{attack_history}{$type}{ $combatant->id } = \@attack_history;

        for ( 1 .. $number_of_attacks ) {
            push @sorted_combatants, $combatant;
        }
    }

    @sorted_combatants = $self->sort_combatant_list(@sorted_combatants);

    return @sorted_combatants;
}

sub sort_combatant_list {
    my $self       = shift;
    my @combatants = @_;

    return shuffle @combatants;
}

sub check_skills {
    my $self = shift;

    my @messages;

    my $character_weapons = $self->character_weapons;

    foreach my $char_id ( keys %$character_weapons ) {
        my $character = $self->combatants_by_id->{character}{$char_id};

        next if !$character || $character->is_dead;

        foreach my $skill ( keys %{ $character_weapons->{$char_id}{skills} } ) {
            $self->log->debug("Checking $skill skill for character $char_id");

            my $char_skill = $character->get_skill($skill);

            my $defender;
            if ( $char_skill->needs_defender ) {
                try {
                    $defender = $self->select_opponent($character);
                }
                catch {
                    $self->log->debug("Error finding opponent: $_");
                };

                return unless $defender;
            }

            my %results = $char_skill->execute( 'combat', $character, $defender );

            if ( $results{fired} ) {
                push @messages, $results{message};

                if ( $results{factor_changed} ) {
                    $self->refresh_factor_cache( 'character', $char_id );
                }

                if ( $defender && $defender->is_dead ) {
                    $self->combatants_alive->{ $self->opponent_number_of_being($defender) }--;
                }

            }
        }

    }

    return @messages;
}

sub select_opponent {
    my $self      = shift;
    my $character = shift;

    my %opponents = map { $_->id => $_ } $self->opposing_combatants_of($character);

    my $opponent;

    # If they've selected a target, or have one saved from last round make sure it's still alive
    my $targetted_opponent_id = $character->last_combat_param1 || $self->session->{previous_opponents}{ $character->id };

    if ( $targetted_opponent_id && $opponents{$targetted_opponent_id} && !$opponents{$targetted_opponent_id}->is_dead ) {
        $opponent = $opponents{$targetted_opponent_id};
    }

    # If we don't have a target, choose one randomly
    unless ($opponent) {
        for my $id ( shuffle keys %opponents ) {
            if ( !$opponents{$id}->is_dead ) {
                $opponent = $opponents{$id};
                last;
            }
        }

        unless ($opponent) {

            # No living opponent found, something weird has happened
            confess "Couldn't find an opponent to attack!\n";
        }
    }

    # Save opponent in session for next round so they keep attacking the same guy
    #  (Unless they die, or they target someone else)
    $self->session->{previous_opponents}{ $character->id } = $opponent->id;

    return $opponent;
}

sub character_action {
    my ( $self, $character ) = @_;

    # Check if spell casters should do an auto cast
    my $autocast = $character->last_combat_param1 && $character->last_combat_param1 eq 'autocast' ? 1 : 0;
    my ( $spell, $target ) = $self->check_for_auto_cast($character);
    if ($spell) {
        return unless $target;
        $self->log->debug( $character->name . " is autocasting " . $spell->spell_name . " on " . $target->name );
        $character->last_combat_action('Cast');
        $character->last_combat_param1( $spell->id );
        $character->last_combat_param2( $target->id );
    }
    elsif ($autocast) {

        # They have auto-cast set, but didn't cast a spell.
        # If they can attack, they should. Otherwise they do nothing.
        # XXX: we don't pass in attack history, but this should usually be OK
        my $number_of_attacks = $character->number_of_attacks();

        return if $number_of_attacks < 1;

        $character->last_combat_action('Attack');
        $character->last_combat_param1(undef);
        $character->last_combat_param2(undef);
    }

    my $result;

    if ( $character->last_combat_action eq 'Attack' ) {

        my $opponent = $self->select_opponent($character);

        my ( $damage, $crit ) = $self->attack( $character, $opponent );

        # Store damage done for XP purposes
        my %action_params;
        if ( ref $damage ) {
            %action_params = %$damage;
        }
        else {
            $action_params{damage} = $damage;
        }

        $result = RPG::Combat::ActionResult->new(
            attacker     => $character,
            defender     => $opponent,
            critical_hit => $crit,
            %action_params,
        );

        if ( my $type = $self->character_weapons->{ $character->id }{magical_damage_type} ) {
            $self->apply_magical_damage(
                $character, $opponent, $result, $type,
                $self->character_weapons->{ $character->id }{magical_damage_level}
            );

            # Force refresh of value
            $result->defender_killed( $opponent->is_dead );
        }
    }
    elsif ( $character->last_combat_action eq 'Cast' || $character->last_combat_action eq 'Use' ) {

        # Cannot cast or use more than once per round
        if ( $self->{_cast_this_round}{ $character->id } ) {
            return;
        }
        $self->{_cast_this_round}{ $character->id } = 1;

        my $obj;
        my $target_type;
        my $action;
        my $blocked = 0;
        if ( $character->last_combat_action eq 'Cast' ) {
            if ( grep { $_->effect->modified_stat eq 'block_spell_casting' } $character->character_effects ) {

                # Spell casting blocked...
                $blocked = 1;
            }

            $obj = $self->schema->resultset('Spell')->find( $character->last_combat_param1 );

            $target_type = $obj->target;

            $action = 'casts ' . $obj->spell_name;
        }
        else {
            $obj = $character->get_item_action( $character->last_combat_param1 );

            $target_type = $obj->target;

            $action = 'uses item';
        }

        my $target;
        if ( $target_type eq 'character' ) {
            $target = $self->combatants_by_id->{'character'}{ $character->last_combat_param2 } ||
              $self->combatants_by_id->{'creature'}{ $character->last_combat_param2 };
        }
        elsif ( $target_type eq 'self' ) {
            $target = $character;
        }
        else {
            $target = $self->opponent_of_by_id( $character, $character->last_combat_param2 );
        }

        if ($blocked) {
            $result = RPG::Combat::SpellActionResult->new(
                defender   => $target,
                attacker   => $character,
                spell_name => $obj->spell_name,
                blocked    => 1,
                type       => 'blocked',
            );
        }
        elsif ( !$target->is_dead ) {
            if ( $character->last_combat_action eq 'Cast' ) {
                $result = $obj->cast( $character, $target );
            }
            else {
                $result = $obj->use($target);
            }

            $self->log->debug( $character->name . ' ' . $action . ' on ' . $target->name . ' (damage: ' . $result->damage . ')' );

            # Since effects could have changed an af or df, we re-calculate the target's factors
            $self->refresh_factor_cache( $target_type, $character->last_combat_param2 );

            # Make sure any healing/damage etc. is taken into account
            $target->discard_changes if $target;

            $self->session->{spells_cast}{ $character->id }++;
            $self->combat_log->spells_cast( $self->combat_log->spells_cast + 1 );
        }
        else {
            $self->log->debug( $character->name . " skips '$action' as target is dead" );
        }

        $character->last_combat_action('Attack');
    }

    # If they were auto-casting, set them back to auto-cast for next round
    if ($autocast) {
        $character->last_combat_action('Cast');
        $character->last_combat_param1('autocast');
        $character->last_combat_param2(undef);
    }
    $character->update;

    return $result;

}

sub apply_magical_damage {
    my $self          = shift;
    my $character     = shift;
    my $opponent      = shift;
    my $action_result = shift;
    my $type          = shift;
    my $level         = shift;

    return if $action_result->damage == 0 || $opponent->is_dead;

    my $package = 'RPG::Combat::MagicalDamage::' . $type;

    my $magical_damage_result = $package->apply(
        character      => $character,
        opponent       => $opponent,
        opponent_group => $self->opponents_of($character),
        level          => $level,
        schema         => $self->schema,
    );

    $action_result->magical_damage($magical_damage_result);
}

sub check_for_auto_cast {
    my $self   = shift;
    my $caster = shift;

    return unless $caster->is_spell_caster;

    # Can only auto-cast once per round
    return if $self->{_auto_cast_checked_for}{ $caster->id };
    $self->{_auto_cast_checked_for}{ $caster->id } = 1;

    my $redo_count = 0;
    my @spell_ids_tried;
    {
        if ( my $spell = $caster->check_for_auto_cast(@spell_ids_tried) ) {
            my $target;

            # Randomly select a target
            for ( $spell->target ) {
                if ( $_ eq 'creature' ) {
                    my @opponents = grep { !$_->is_dead } $self->opposing_combatants_of($caster);

                    $target = $spell->select_target(@opponents);
                }
                elsif ( $_ eq 'character' ) {
                    my $group = $caster->group;
                    my @chars = grep { !$_->is_dead && $group->has_being($_) } $self->combatants;

                    $target = $spell->select_target(@chars);
                }
                elsif ( $_ eq 'party' ) {
                    my $opp_num = $self->opponent_number_of_being($caster);
                    $target = ( $self->opponents )[ $opp_num - 1 ];
                }
                else {
                    # Currently only combat spells with creature/character target are implemented
                    confess "Auto-cast can't handle spell target: $_";
                }
            }

            if ( !$target ) {
                $redo_count++;
                return if $redo_count > 5;
                push @spell_ids_tried, $spell->id;
                redo;
            }

            return ( $spell, $target );
        }
    }
}

sub creature_action {
    my ( $self, $creature ) = @_;

    my $party = $self->opponents_of($creature);

    my ( $spell, $target ) = $self->check_for_auto_cast($creature);
    if ($spell) {
        return $spell->creature_cast( $creature, $target );
    }

    my @characters = sort { ( $a->party_order || 0 ) <=> ( $b->party_order || 0 ) } $self->opposing_combatants_of($creature);
    @characters = grep { !$_->is_dead } @characters;    # Get rid of corpses

    # Figure out whether creature will target front or back rank
    my $rank_pos = $party->rank_separator_position;

    $rank_pos = scalar @characters if $rank_pos > scalar @characters;

    # Any character in the front-rank gets put in the char list twice
    if ( scalar @characters > 1 ) {
        my @front_rank_chars;
        foreach my $char (@characters) {
            if ( $char->in_front_rank($rank_pos) ) {
                push @front_rank_chars, $char;
            }
        }

        @characters = ( @front_rank_chars, @characters );
    }

    my $character;
    foreach my $char_to_check ( $self->sort_creature_targets(@characters) ) {
        unless ( $char_to_check->is_dead ) {
            $character = $char_to_check;
            last;
        }
    }

    unless ($character) {
        confess "Couldn't find a character to attack!\n";
    }

    # Count number of times attacked for XP purposes
    $self->session->{attack_count}{ $character->id }++;

    my ( $damage, $crit ) = $self->attack( $creature, $character );

    my $action_result = RPG::Combat::ActionResult->new(
        attacker     => $creature,
        defender     => $character,
        damage       => $damage,
        critical_hit => $crit,
    );

    if ( $creature->type->special_damage ) {
        $self->apply_magical_damage(
            $creature, $character, $action_result, $creature->type->special_damage, int $creature->type->level / 3
        );
    }

    return $action_result;
}

sub sort_creature_targets {
    my $self    = shift;
    my @targets = @_;

    return shuffle @targets;
}

sub attack {
    my $self = shift;
    my ( $attacker, $defender ) = @_;

    my $attacker_type = $attacker->is_character ? 'character' : 'creature';

    $self->log->debug("About to check attack");

    if ( $attacker_type eq 'character' ) {
        my $attack_error = $self->check_character_attack($attacker);

        $self->log->debug( "Got attack error: " . Dumper $attack_error) if $attack_error;
        return $attack_error if $attack_error;
    }

    my $defending = 0;
    if ( $defender->is_character && $defender->last_combat_action eq 'Defend' ) {
        $defending = 1;
    }

    $self->log->debug("About to execute defence");

    if ( $defender->is_character and my $defence_message = $self->check_character_defence($defender) ) {
        if ( $defence_message->{armour_broken} ) {

            # Armour has broken, clear out this character's factor cache
            $self->refresh_factor_cache( 'character', $defender->id );
        }
    }

    my $hit  = 0;
    my $crit = 0;

    # Check for critical hit
    my $chance = $self->combat_factors->{ $attacker->is_character ? 'character' : 'creature' }{ $attacker->id }{crit_hit} // 0;
    my $roll = Games::Dice::Advanced->roll('1d100');

    $self->log->debug( "Executing attack. Attacker: " . $attacker->name . ", Defender: " . $defender->name );
    $self->log->debug("Checking for critical hit: chance: $chance, roll: $roll");

    if ( $roll <= $chance ) {
        $self->log->debug("Critical hit!");
        $hit  = 1;
        $crit = 1;
    }
    else {
        my $a_roll = Games::Dice::Advanced->roll( '1d' . $self->config->{attack_dice_roll} );
        my $d_roll = Games::Dice::Advanced->roll( '1d' . $self->config->{defence_dice_roll} );

        my $defence_bonus = $defending ? $self->config->{defend_bonus} : 0;

        my $af = $self->combat_factors->{ $attacker->is_character ? 'character' : 'creature' }{ $attacker->id }{af};

        if ( $attacker->is_character && !$defender->is_character ) {
            if ( my $bonuses = $self->character_weapons->{ $attacker->id }{creature_bonus} ) {
                $af += $bonuses->{ $defender->type->category->id } || 0;
            }
        }

        my $df = $self->combat_factors->{ $defender->is_character ? 'character' : 'creature' }{ $defender->id }{df};

        my $aq = $af - $a_roll;
        my $dq = $df + $defence_bonus - $d_roll;

        $self->log->debug("Attack:  Factor: $af Roll: $a_roll  Quotient: $aq");
        $self->log->debug("Defence: Factor: $df Roll: $d_roll  Quotient: $dq Bonus: $defence_bonus ");

        if ( $aq > $dq ) {
            $hit = 1;
        }
    }

    my $damage = 0;

    if ($hit) {

        # Attack hits
        my $dam_max = $self->combat_factors->{ $attacker->is_character ? 'character' : 'creature' }{ $attacker->id }{dam};
        $damage = Games::Dice::Advanced->roll( '1d' . $dam_max )
          unless $dam_max <= 0;

        $self->log->debug( "Defender current hps: " . $defender->hit_points_current );

        $defender->hit( $damage, $attacker );

        $self->session->{stalemate_check} += $damage;

        $self->log->debug("Attack hits. Damage: $damage");
    }

    return ( $damage, $crit );
}

sub check_character_attack {
    my ( $self, $attacker ) = @_;

    return unless defined $self->character_weapons->{ $attacker->id }{id};

    unless ( $self->character_weapons->{ $attacker->id }{indestructible} ) {
        my $weapon_durability = $self->character_weapons->{ $attacker->id }{durability} || 0;

        return { weapon_broken => 1 } if $weapon_durability == 0;

        my $weapon_damage_roll = Games::Dice::Advanced->roll('1d3');

        if ( $weapon_damage_roll == 1 ) {

            $self->log->debug('Reducing durability of weapon');
            $weapon_durability--;

            $self->character_weapons->{ $attacker->id }{durability} = $weapon_durability;
        }

        if ( $weapon_durability <= 0 ) {

            # Weapon broken
            my $item = $self->schema->resultset('Items')->find(
                {
                    item_id => $self->character_weapons->{ $attacker->id }{id},
                },
                {
                    prefetch => 'item_variables',
                },
            );
            $item->variable( 'Durability', 0 );
            $attacker->calculate_attack_factor;
            $attacker->update;

            return { weapon_broken => 1 };
        }
    }

    if ( ref $self->character_weapons->{ $attacker->id }{ammunition} eq 'ARRAY' ) {

        $self->log->debug('Checking for ammo');
        my $ammo_found = 0;
        foreach my $ammo ( @{ $self->character_weapons->{ $attacker->id }{ammunition} } ) {
            next unless $ammo;

            $ammo_found = 1 if $ammo->{quantity} > 0;

            $ammo->{quantity}--;
            if ( $ammo->{quantity} <= 0 ) {

                # Ammo used up, so delete it
                my $item = $self->schema->resultset('Items')->find( { item_id => $ammo->{id}, }, );
                $attacker->remove_item_from_grid($item);
                $item->delete;
                $ammo = undef;
            }
            else {
                # Update with new ammo amount
                $self->schema->resultset('Item_Variable')->find(
                    {
                        item_id                                 => $ammo->{id},
                        'item_variable_name.item_variable_name' => 'Quantity',
                    },
                    { join => 'item_variable_name', }
                )->update( { item_variable_value => $ammo->{quantity}, } );
            }

            last if $ammo_found;
        }

        if ( !$ammo_found ) {
            return { no_ammo => 1 };
        }
    }

    return;
}

sub check_character_defence {
    my ( $self, $defender ) = @_;

    return unless defined $self->character_weapons->{ $defender->id }{armour};

    my $armour = $self->character_weapons->{ $defender->id }{armour};

    foreach my $item_id ( keys %$armour ) {
        my $weapon_damage_roll = Games::Dice::Advanced->roll('1d3');
        $armour->{$item_id}-- if $weapon_damage_roll == 1;

        $self->log->debug( "Armour $item_id durability now: " . $armour->{$item_id} );

        if ( $armour->{$item_id} == 0 ) {

            # Armour broken
            my $item = $self->schema->resultset('Items')->find(
                {
                    item_id => $item_id,
                },
                {
                    prefetch => 'item_variables',
                },
            );
            $item->variable( 'Durability', 0 );
            $defender->calculate_defence_factor;
            $defender->update;

            return { armour_broken => 1 };
        }
    }

    return;
}

# Party (or garrison) attempts to flee
# Param passed is party's opponent number
sub party_flee {
    my $self       = shift;
    my $opp_number = shift;

    my @opponents = $self->opponents;

    my $party = $opponents[ $opp_number - 1 ];
    my $opponent = $opponents[ $opp_number == 1 ? 1 : 0 ];

    my $flee_attempts_column = 'opponent_' . $opp_number . '_flee_attempts';
    $self->combat_log->set_column( $flee_attempts_column, ( $self->combat_log->get_column($flee_attempts_column) || 0 ) + 1 );

    my $flee_successful = $self->roll_flee_attempt( $party, $opponent, $opp_number );
    if ($flee_successful) {
        my $sector = $self->get_sector_to_flee_to($party);

        $party->move_to($sector);
        $party->update;

        $self->combat_log->outcome( 'opp' . $opp_number . '_fled' );
        $self->combat_log->encounter_ended( DateTime->now() );

        return 1;
    }
}

sub roll_flee_attempt {
    my $self             = shift;
    my $fleers           = shift;
    my $opponents        = shift;
    my $fleer_opp_number = shift;

    my $flee_attempts_column = 'opponent_' . $fleer_opp_number . '_flee_attempts';
    my $flee_chance = $fleers->flee_chance( $opponents, $self->combat_log->get_column($flee_attempts_column) );

    my $rand = Games::Dice::Advanced->roll("1d100");

    $self->log->debug("Flee roll: $rand");
    $self->log->debug( "Flee chance: " . $flee_chance );

    return $rand <= $flee_chance ? 1 : 0;
}

sub end_of_combat_cleanup {
    my $self = shift;

    foreach my $opponent ( $self->opponents ) {
        if ( $opponent->can('end_combat') && $opponent->in_storage ) {
            $opponent->end_combat;
        }
    }

    foreach my $combatant ( $self->combatants ) {
        next unless $combatant->is_character;

        # Remove character effects from this combat
        foreach my $effect ( $combatant->character_effects ) {
            $effect->delete if $effect->effect->combat;
        }

        # Remove last_combat_actions that can't be carried between combats
        if ( $combatant->last_combat_action eq 'Cast' || $combatant->last_combat_action eq 'Use' ) {
            $combatant->last_combat_action('Attack');
        }
        $combatant->last_combat_param1(undef);
        $combatant->last_combat_param2(undef);
        $combatant->update;

        # Update armour durability
        my $armour = $self->character_weapons->{ $combatant->id }{armour};
        if ($armour) {
            my @items = $self->schema->resultset('Items')->search(
                {
                    'me.item_id' => [ keys %$armour ],
                },
                {
                    prefetch => 'item_variables',
                },
            );

            foreach my $item (@items) {
                $item->variable( 'Durability', $armour->{ $item->id } );
            }
        }

        # Update weapon durability
        if ( $self->character_weapons->{ $combatant->id }{id} ) {
            my $weapon = $self->schema->resultset('Items')->find(
                {
                    'me.item_id' => $self->character_weapons->{ $combatant->id }{id},
                },
                {
                    prefetch => 'item_variables',
                },
            );

            $weapon->variable( 'Durability', $self->character_weapons->{ $combatant->id }{durability} );
        }
    }
}

sub distribute_xp {
    my ( $self, $xp, $char_ids ) = @_;

    my %awarded_xp;
    $xp //= 0;    # Everyone gets 10% to start with
    my $min_xp = int $xp * 0.1;
    @awarded_xp{@$char_ids} = ($min_xp) x scalar @$char_ids;
    $xp -= $min_xp * scalar @$char_ids;

    # Work out total damage, total attacks made and total spells cast
    my ( $total_damage, $total_attacks, $total_spells_cast ) = ( 0, 0, 0 );
    map { $total_damage      += $_ } values %{ $self->session->{damage_done} };
    map { $total_attacks     += $_ } values %{ $self->session->{attack_count} };
    map { $total_spells_cast += $_ } values %{ $self->session->{spells_cast} };

    my $total_awarded = 0;

    # Weighting depend on whether any spells were cast
    my ( $damage_weight, $attack_weight, $spell_weight );
    if ( $total_spells_cast <= 0 ) {
        $damage_weight = 0.6;
        $attack_weight = 0.4;
        $spell_weight  = 0;
    }
    else {
        $damage_weight = 0.5;
        $attack_weight = 0.25;
        $spell_weight  = 0.25;
    }

    # Assign each character XP points, up to a max of 35% of the pool
    foreach my $char_id (@$char_ids) {
        my ( $damage_percent, $attacked_percent, $spells_percent ) = ( 0, 0, 0 );

        $damage_percent = ( ( $self->session->{damage_done}{$char_id} || 0 ) / $total_damage ) * $damage_weight
          if $total_damage > 0;
        $attacked_percent = ( ( $self->session->{attack_count}{$char_id} || 0 ) / $total_attacks ) * $attack_weight
          if $total_attacks > 0;
        $spells_percent = ( ( $self->session->{spells_cast}{$char_id} || 0 ) / $total_spells_cast ) * $spell_weight
          if $total_spells_cast > 0;

        my $total_percent = $damage_percent + $attacked_percent + $spells_percent;
        $total_percent = 0.35 if $total_percent > 0.35;

        my $xp_awarded = round $xp * $total_percent;

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

    my $combat_log = $self->schema->resultset('Combat_Log')->find(
        {
            opponent_1_id   => $opp1->id,
            opponent_1_type => $opp1->group_type,
            opponent_2_id   => $opp2->id,
            opponent_2_type => $opp2->group_type,
            encounter_ended => undef,
        },
        {
            for => 'update',
        },
    );

    if ( !$combat_log ) {
        $combat_log = $self->schema->resultset('Combat_Log')->create(
            {
                opponent_1_id       => $opp1->id,
                opponent_1_type     => $opp1->group_type,
                opponent_2_id       => $opp2->id,
                opponent_2_type     => $opp2->group_type,
                encounter_started   => DateTime->now(),
                combat_initiated_by => $self->initiated_by,
                opponent_1_level    => $opp1->level,
                opponent_2_level    => $opp2->level,
                game_day    => $self->schema->resultset('Day')->find_today->id,
                spells_cast => 0,

                $self->combat_log_location_attribute => $self->location->id,
            },
        );
    }

    return $combat_log;
}

# Refresh a combatant's details in the factor cache
sub refresh_factor_cache {
    my ( $self, $combatant_type, $combatant_id_to_refresh ) = @_;

    $self->log->debug("refresh factors: $combatant_type $combatant_id_to_refresh");

    delete $self->session->{combat_factors}{$combatant_type}{$combatant_id_to_refresh}
      if defined $self->session->{combat_factors}{$combatant_type}{$combatant_id_to_refresh};

    $self->combat_factors( $self->_build_combat_factors( $combatant_type, $combatant_id_to_refresh ) );
}

sub _build_combat_factors {
    my $self         = shift;
    my $refresh_type = shift;
    my $id           = shift;

    my %combat_factors;

    %combat_factors = %{ $self->session->{combat_factors} } if defined $self->session->{combat_factors};

    # If we don't have any chars or creatures set, we must be 'initialising'
    #  (i.e. not just refreshing an individual combatant)
    my $initialising = ( $combat_factors{creature} && %{ $combat_factors{creature} } ) ||
      ( $combat_factors{character} && %{ $combat_factors{character} } ) ? 0 : 1;

    foreach my $combatant ( $self->combatants ) {
        next if $combatant->is_dead;

        my $type = $combatant->is_character ? 'character' : 'creature';

        # If we've been asked to build a particular combatant's factors, and we're not initialising,
        #  skip anyone who is not that combatant
        if ( defined $id && !$initialising ) {
            next unless $id == $combatant->id && $type eq $refresh_type;
        }

        next if defined $combat_factors{$type}{ $combatant->id };

        $combat_factors{$type}{ $combatant->id }{af} = $combatant->attack_factor;
        $combat_factors{$type}{ $combatant->id }{df} = $combatant->defence_factor;
        $combat_factors{$type}{ $combatant->id }{dam} = $combatant->damage;
        $combat_factors{$type}{ $combatant->id }{crit_hit} = $combatant->critical_hit_chance;
    }

    $self->session->{combat_factors} = \%combat_factors;

    return \%combat_factors;
}

sub _build_character_weapons {
    my $self = shift;

    my %character_weapons;

    return $self->session->{character_weapons} if defined $self->session->{character_weapons};

    my @combat_skills = $self->schema->resultset('Skill')->search(
        {
            type => 'combat',
        }
    );

    foreach my $combatant ( $self->combatants ) {
        next unless $combatant->is_character;

        my ($weapon) = $combatant->get_equipped_item('Weapon');

        if ($weapon) {
            $character_weapons{ $combatant->id }{id} = $weapon->id;
            $character_weapons{ $combatant->id }{durability} = $weapon->variable('Durability');
            $character_weapons{ $combatant->id }{indestructible} = $weapon->variable('Indestructible');
            $character_weapons{ $combatant->id }{ammunition} = $combatant->ammunition_for_item($weapon);
            $character_weapons{ $combatant->id }{magical_damage_type} = $weapon->variable('Magical Damage Type');
            $character_weapons{ $combatant->id }{magical_damage_level} = $weapon->variable('Magical Damage Level');
            $character_weapons{ $combatant->id }{weapon_name} = $combatant->weapon($weapon);
            $character_weapons{ $combatant->id }{is_ranged} = $weapon->item_type->category->item_category eq 'Ranged Weapon' ? 1 : 0;

            my @enchantments = $weapon->item_enchantments;
            my %creature_bonus;
            foreach my $enchantment (@enchantments) {
                if ( $enchantment->enchantment->enchantment_name eq 'bonus_against_creature_category' ) {
                    $creature_bonus{ $enchantment->variable('Creature Category') } = $enchantment->variable('Bonus');
                }
            }

            $character_weapons{ $combatant->id }{creature_bonus} = \%creature_bonus;
        }
        else {
            $character_weapons{ $combatant->id }{durability} = 1;
        }

        # And armour...
        my @items = $combatant->get_equipped_item( 'Armour', 1 );

        foreach my $item (@items) {
            next if $item->variable('Indestructible');

            my $dur = $item->variable('Durability');

            next unless $dur;

            $character_weapons{ $combatant->id }{armour}{ $item->id } = $item->variable('Durability');
        }

        # Also cache any combat skills
        foreach my $skill (@combat_skills) {
            my $skill_name = $skill->skill_name;
            my $char_skill = $combatant->get_skill($skill_name);

            # XXX: if we passed the $char_skill object to this cache, it would save
            #  the need to re-read it in check_skills(). However, because some Moose magick
            #  re-blesses it (when dynamically applying the role), it can't be thawed properly
            $character_weapons{ $combatant->id }{skills}{$skill_name} = 1
              if $char_skill;
        }
    }

    $self->session->{character_weapons} = \%character_weapons;

    return \%character_weapons;
}

sub _build_combatants_by_id {
    my $self = shift;

    my %combatants_by_id;

    foreach my $combatant ( $self->combatants ) {
        my $type = $combatant->is_character ? 'character' : 'creature';
        $combatants_by_id{$type}{ $combatant->id } = $combatant;
    }

    return \%combatants_by_id;
}

sub _build_combatants_alive {
    my $self = shift;

    return $self->session->{combatants_alive} if defined $self->session->{combatants_alive};

    my @opps = $self->opponents;

    my %number_alive;
    for my $opp ( 1 .. 2 ) {
        $number_alive{$opp} = $opps[ $opp - 1 ]->number_alive;
    }

    $self->session->{combatants_alive} = \%number_alive;

    return \%number_alive;

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
