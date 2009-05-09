package RPG::Schema::Spell::Haste;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use Games::Dice::Advanced;

sub _cast {
    my ( $self, $character, $target ) = @_;

    my $duration = 2 * ( int $character->level / 3 + 1 );

    $self->create_effect(
        {
            target      => $target,
            effect_name    => 'Haste',
            duration       => $duration,
            modifier       => 0.5,
            combat         => 1,
            modified_state => 'attack_frequency',
        }

    );

    return {
        type     => 'effect',
        duration => $duration,
        effect   => 'speeding his attack',
    };
}

1;
