package RPG::Schema::Spell::Energy_Beam;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use Games::Dice::Advanced;

sub _cast {
    my ( $self, $character, $target_creature, $level ) = @_;

    my $dice_count = int $level / 5 + 1;

    my $beam = Games::Dice::Advanced->roll( $dice_count . "d6" );

    $target_creature->hit( $beam, $character );
    $target_creature->update;

    return {
        type   => 'damage',
        damage => $beam,
        effect => 'zapping',
    };
}

1;
