package RPG::Schema::Spell::Ice_Bolt;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use Games::Dice::Advanced;

sub _cast {
    my ( $self, $character, $target, $level ) = @_;
    my $dice_count = int $level / 3 + 1;

    my $bolt = Games::Dice::Advanced->roll( $dice_count . "d4" );

    my $resisted = $target->hit_with_resistance( 'Ice', $bolt, $character );
    $target->update;

    $self->create_effect(
        {
            target         => $target,
            effect_name    => 'Frozen',
            duration       => $dice_count,
            modifier       => -0.5,
            combat         => 1,
            modified_state => 'attack_frequency',
        }
    ) if !$resisted;

    return {
        type     => 'damage',
        damage   => $bolt,
        effect   => 'freezing',
        resisted => $resisted,
    };
}

1;
