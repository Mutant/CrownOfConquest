package RPG::Schema::Spell::Flame;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use Games::Dice::Advanced;

sub _cast {
    my ( $self, $character, $target ) = @_;
    my $dice_count = int $character->level / 3 + 1;

    my $flame = Games::Dice::Advanced->roll( $dice_count . "d10" );

    $target->change_hit_points( -$flame );
    $target->update;

    return {
        type   => 'damage',
        damage => $flame,
        effect => 'frying',
    };
}

1;
