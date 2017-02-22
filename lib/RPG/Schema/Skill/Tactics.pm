package RPG::Schema::Skill::Tactics;

use Moose::Role;

use Math::Round qw(round);

sub execute {
    my $self  = shift;
    my $event = shift;

    my $character = $self->char_with_skill;

    if ( $event eq 'opponent_flee' ) {
        return round $self->level + ( $character->intelligence / 8 );
    }
    elsif ('guard_af') {
        return $self->level;
    }
}

1;
