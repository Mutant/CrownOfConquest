package RPG::Combat::CreatureBattle;

use Mouse::Role;

use Data::Dumper;
use Games::Dice::Advanced;

with 'RPG::Combat::Battle';

has 'party'              => ( is => 'rw', isa => 'RPG::Schema::Party',         required => 1 );
has 'creature_group'     => ( is => 'rw', isa => 'RPG::Schema::CreatureGroup', required => 1 );
has 'creatures_can_flee' => ( is => 'ro', isa => 'Bool',                       default  => 1 );

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
    
    return 0 unless $self->creatures_can_flee;

    # See if the creatures want to flee... check this every 3 rounds
    #  Only flee if cg level is lower than party
    #$c->log->debug("Checking for creature flee");
    #$c->log->debug( "Round: " . $c->stash->{combat_log}->rounds );
    #$c->log->debug( "CG level: " . $c->stash->{creature_group}->level );
    #$c->log->debug( "Party level: " . $c->stash->{party}->level );

    if ( $self->combat_log->rounds != 0 && $self->combat_log->rounds % 3 == 0 ) {
        if ( $self->creature_group->level < $self->party->level - 2 ) {
            my $chance_of_fleeing =
                ( $self->party->level - $self->creature_group->level ) * $self->config->{chance_creatures_flee_per_level_diff};

            #$c->log->debug("Chance of creatures fleeing: $chance_of_fleeing");

            if ( $chance_of_fleeing >= Games::Dice::Advanced->roll('1d100') ) {
                # Creatures flee
                my $land = $self->get_sector_to_flee_to(1);

                $self->creature_group->land_id( $land->id );
                $self->creature_group->update;

                $self->party->in_combat_with(undef);
                $self->party->update;

                #$c->stash->{messages} = "The creatures have fled!";

                $self->combat_log->outcome('creatures_fled');
                $self->combat_log->encounter_ended( DateTime->now() );
                
                return 1;
            }
        }
    }

    return 0;
}

1;
