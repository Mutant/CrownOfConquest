package RPG::Schema::Spell::Entangle;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use Games::Dice::Advanced;

sub _cast {
    my ( $self, $character, $target, $level ) = @_;

    my $duration = 3 + ( int $level / 5 + 1 );

    $self->create_effect(
        {
            target      => $target,
            effect_name    => 'Entangled',
            duration       => $duration,
            modifier       => -10000,
            combat         => 1,
            modified_state => 'attack_frequency',
        }
    );

    return {
        type     => 'effect',
        duration => $duration,
        effect   => 'entangling ' . $target->pronoun('objective'),
    };
}

1;
