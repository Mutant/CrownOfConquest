package RPG::Schema::Skill::Charisma;

use Moose::Role;

use Math::Round;

sub execute {
    my $self  = shift;
    my $event = shift;

    my $character = $self->char_with_skill;

    if ( $event eq 'mayor_approval' ) {
        return round( $self->level / 2 );
    }
    elsif ( $event eq 'election' ) {
        return $self->level * 2 + round( $character->intelligence / 2 );
    }
    elsif ( $event eq 'kingdom_loyalty' ) {
        return round( $self->level / 2 );
    }
    elsif ( $event eq 'mayor_xp_gain' ) {
        return $self->level;
    }

}

1;
