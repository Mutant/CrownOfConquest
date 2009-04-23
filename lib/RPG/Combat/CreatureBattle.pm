package RPG::Combat::CreatureBattle;

use Mouse;

use Data::Dumper;

with 'RPG::Combat::Battle';

has 'party'          => ( is => 'rw', isa => 'RPG::Schema::Party',         required => 1 );
has 'creature_group' => ( is => 'rw', isa => 'RPG::Schema::CreatureGroup', required => 1 );

sub combatants {
    my $self = shift;
    
    return ($self->party->characters, $self->creature_group->creatures);   
}

sub opponents_of {
    my $self = shift;
    my $being = shift;
    
    if ($being->is_character) {
        return $self->creature_group;   
    }
    else {
        return $self->party;   
    }
}

sub process_effects  {
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

    $self->_process_effects(@character_effects, @creature_effects);

    # Refresh party / creature_group in stash if necessary
    # TODO: decide if we should be doing this here
    if (@creature_effects) {
        $self->creature_group($self->schema->resultset('CreatureGroup')->get_by_id( $self->creature_group->id ));
    }

    if (@character_effects) {
        $self->party($self->schema->resultset('Party')->get_by_player_id( $self->party->player_id ));
    }
}

1;
