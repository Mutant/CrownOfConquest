package RPG::Schema::Spell::Weaken;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use Games::Dice::Advanced;

sub _cast {
    my ( $self, $character, $target, $level ) = @_;

    my $modifier = 0 - $level;
    my $duration = 2 * ( int $level / 3 + 1 );

    $self->create_effect(
        {
            target         => $target,
            effect_name    => 'Weakened',
            duration       => $duration,
            modifier       => $modifier,
            combat         => 1,
            modified_state => 'damage',
        }
    );
    return {
        type     => 'effect',
        duration => $duration,
        effect   => 'weakening ' . $target->pronoun('objective'),
    };
}

1;
