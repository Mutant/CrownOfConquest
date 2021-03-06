package RPG::Schema::Spell::Curse;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use Games::Dice::Advanced;

sub _cast {
    my ( $self, $character, $target, $level ) = @_;

    my $modifier = 0 - $level;
    my $duration = 2 * ( int $level / 4 + 1 );

    $self->create_effect(
        {
            target         => $target,
            effect_name    => 'Cursed',
            duration       => $duration,
            modifier       => $modifier,
            combat         => 1,
            modified_state => 'attack_factor',
        }
    );

    return {
        type     => 'effect',
        duration => $duration,
        effect   => 'cursing ' . $target->pronoun('objective'),
    };
}

1;
