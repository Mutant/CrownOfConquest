package RPG::Combat::CreatureBattle;

use Moose::Role;

use Data::Dumper;
use Games::Dice::Advanced;

requires qw/creatures_flee_to/;

has 'party'              => ( is => 'rw', isa => 'RPG::Schema::Party',         required => 1 );
has 'creature_group'     => ( is => 'rw', isa => 'RPG::Schema::CreatureGroup', required => 1 );
has 'creatures_can_flee' => ( is => 'ro', isa => 'Bool',                       default  => 1 );
has 'party_flee_attempt' => ( is => 'ro', isa => 'Bool',                       default  => 0 );

sub combatants {
    my $self = shift;

    return ( $self->party->characters, $self->creature_group->creatures );
}

sub opponents {
    my $self = shift;

    return ( $self->party, $self->creature_group );
}

sub opponents_of {
    my $self  = shift;
    my $being = shift;

    if ( $being->is_character ) {
        return $self->creature_group;
    }
    else {
        return $self->party;
    }
}

sub process_effects {
    my $self = shift;

    my @character_effects = $self->schema->resultset('Character_Effect')->search(
        {
            character_id    => [ map { $_->id } $self->party->characters ],
            'effect.combat' => 1,
        },
        { prefetch => 'effect', },
    );

    my @creature_effects = $self->schema->resultset('Creature_Effect')->search(
        {
            creature_id     => [ map { $_->id } $self->creature_group->creatures ],
            'effect.combat' => 1,
        },
        { prefetch => 'effect', },
    );

    $self->_process_effects( @character_effects, @creature_effects );

    # Refresh party / creature_group in stash if necessary
    # TODO: decide if we should be doing this here
    if (@creature_effects) {
        $self->creature_group( $self->schema->resultset('CreatureGroup')->get_by_id( $self->creature_group->id ) );
    }

    if (@character_effects) {
        $self->party( $self->schema->resultset('Party')->get_by_player_id( $self->party->player_id ) );
    }
}

sub check_for_flee {
    my $self = shift;

    if ($self->party_flee_attempt && $self->party_flee) {
        return {party_fled => 1};
    }
    
    return unless $self->creatures_can_flee;
    
    # See if the creatures want to flee... check this every 3 rounds
    #  Only flee if cg level is lower than party
    if ( $self->combat_log->rounds != 0 && $self->combat_log->rounds % 3 == 0 ) {
        if ( $self->creature_group->level < $self->party->level - 2 ) {
            my $chance_of_fleeing =
                ( $self->party->level - $self->creature_group->level ) * $self->config->{chance_creatures_flee_per_level_diff};

            $self->log->debug("Chance of creatures fleeing: $chance_of_fleeing");

            my $roll = Games::Dice::Advanced->roll('1d100');
            
            $self->log->debug("Flee roll: $roll");
            
            if ( $chance_of_fleeing >= $roll) {
                # Creatures flee
                my $land = $self->get_sector_to_flee_to(1);
                
                $self->creatures_flee_to( $land );

                $self->party->in_combat_with(undef);
                $self->party->update;

                $self->combat_log->outcome('opp2_fled');
                $self->combat_log->encounter_ended( DateTime->now() );
                
                return {creatures_fled => 1};
            }
        }
    }

    return;
}

sub roll_flee_attempt {
    my $self = shift;

    my $level_difference = $self->creature_group->level - $self->party->level;
    my $flee_chance =
        $self->config->{base_flee_chance} + ( $self->config->{flee_chance_level_modifier} * ( $level_difference > 0 ? $level_difference : 0 ) );

    if ( $self->party->level == 1 ) {

        # Bonus chance for being low level
        $flee_chance += $self->config->{flee_chance_low_level_bonus};
    }

    $flee_chance += ( $self->config->{flee_chance_attempt_modifier} * $self->session->{unsuccessful_flee_attempts} );

    my $rand = Games::Dice::Advanced->roll("1d100");

    $self->log->debug("Flee roll: $rand");
    $self->log->debug( "Flee chance: " . $flee_chance );

    return $rand <= $flee_chance ? 1 : 0;
}

1;
