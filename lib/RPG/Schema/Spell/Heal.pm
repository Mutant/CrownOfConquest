package RPG::Schema::Spell::Heal;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use Games::Dice::Advanced;

sub _cast {
    my ( $self, $character, $target ) = @_;

    my $dice_count = int $character->level / 5 + 1;

    my $heal = Games::Dice::Advanced->roll( $dice_count . "d6" );

    $target->change_hit_points($heal);
    $target->update;

    return {
        type   => 'damage',
        damage => $heal,
        effect => 'healing',
    };
}

1;
