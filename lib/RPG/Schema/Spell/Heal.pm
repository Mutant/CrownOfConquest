package RPG::Schema::Spell::Heal;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use Games::Dice::Advanced;

sub _cast {
    my ( $self, $character, $target, $level ) = @_;

    my $dice_count = int $level / 5 + 1;

    my $heal = Games::Dice::Advanced->roll( $dice_count . "d6" );

    $target->change_hit_points($heal) unless $target->is_dead;
    $target->update;

    return {
        type   => 'damage',
        damage => $heal,
        effect => 'healing',
    };
}

sub can_be_cast_on {
    my $self   = shift;
    my $target = shift;

    return !$target->is_dead && $target->hit_points_current < $target->hit_points_max;
}

1;
