package RPG::Combat::Battle;

use Mouse::Role;

use List::Util qw(shuffle);
use Carp;

requires qw/combatants process_effects opponents_of/;

has 'schema'          => ( is => 'ro', isa => 'RPG::Schema',           required => 1 );
has 'combat_complete' => ( is => 'rw', isa => 'Bool',                  default  => 0 );
has 'attack_history'  => ( is => 'ro', isa => 'HashRef[HashRef[ArrayRef[Int]]]', required => 0 );

sub execute_round {
    my $self = shift;

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

        # TODO: not sure where this goes...

=comment        
        if ( $self->combat_complete || $c->stash->{party}->defunct ) {
            push @{ $c->stash->{refresh_panels} }, 'map';
            last;
        }
=cut

    }

=comment
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
=cut

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
        
        my $type = $combatant->is_character ? 'character' : 'creatures';
        
        @attack_history = @{ $self->attack_history->{$type}{ $combatant->id } }
            if $self->attack_history->{$type}{ $combatant->id };

        my $number_of_attacks = $combatant->number_of_attacks(@attack_history);

        $self->{attacks_this_round}{$type}{$combatant->id} = $number_of_attacks;

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

        # If they've selected a target, make sure it's still alive
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

        $damage = $self->attack($character, $opponent);

        # Store damage done for XP purposes
        $self->{damage_done}{ $character->id } = $damage unless ref $damage;

        # If creature is now dead, see if any other creatures are left alive.
        #  If not, combat is over.
        if ( $opponent->is_dead && $opp_group->number_alive == 0 ) {

            # TODO: sort out combat log
            # We don't actually do any of the stuff to complete the combat here, so a
            #  later action can still display monsters, messages, etc.
            #$c->stash->{combat_log}->outcome('party_won');
            #$c->stash->{combat_log}->encounter_ended( DateTime->now() );

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

sub attack {
    return 1;   
}

1;
