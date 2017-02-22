package RPG::Schema::Spell::Flame;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use Games::Dice::Advanced;

sub _cast {
    my ( $self, $character, $target, $level ) = @_;
    my $dice_count = int $level / 3 + 1;

    my $flame = Games::Dice::Advanced->roll( $dice_count . "d6" );

    my $resisted = $target->hit_with_resistance( 'Fire', $flame, $character );
    $target->update;

    return {
        type     => 'damage',
        damage   => $flame,
        effect   => 'frying',
        resisted => $resisted,
    };
}

1;
