package RPG::Schema::Skill::Awareness;

use Moose::Role;

use Math::Round qw(round);

sub execute {
    my $self  = shift;
    my $event = shift;

    my $character = $self->char_with_skill;

    if ( $event eq 'chest_trap' ) {
        return $self->level + round( $character->intelligence / 4 );
    }
    elsif ( $event eq 'search_room' ) {
        return $self->level + round( $character->divinity / 4 );
    }

}

1;
