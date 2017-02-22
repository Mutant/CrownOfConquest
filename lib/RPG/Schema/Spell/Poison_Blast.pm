package RPG::Schema::Spell::Poison_Blast;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use Games::Dice::Advanced;

sub _cast {
    my ( $self, $character, $target, $level ) = @_;

    my $duration = int( ( $level + 3 ) / 2 );

    my $resisted = $target->resistance_roll('Poison');

    if ( !$resisted ) {
        $self->create_effect(
            {
                target         => $target,
                effect_name    => 'Poisoned',
                duration       => $duration,
                modifier       => int $level / 2,
                combat         => 1,
                modified_state => 'poison',
            }
        );
    }

    return {
        type     => 'effect',
        duration => $duration,
        effect   => 'poisoning ' . $target->pronoun('objective'),
        resisted => $resisted,
    };
}

1;
