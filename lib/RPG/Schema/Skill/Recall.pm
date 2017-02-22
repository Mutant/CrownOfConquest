package RPG::Schema::Skill::Recall;

use Moose::Role;

use Games::Dice::Advanced;
use Data::Dumper;

sub execute {
    my $self  = shift;
    my $event = shift;

    return unless $event eq 'cast';

    my $character = $self->char_with_skill;

    my $chance = $self->level + ( $character->constitution / 12 );

    if ( Games::Dice::Advanced->roll('1d100') <= $chance ) {
        return 1;
    }
    else {
        return 0;
    }
}

1;
