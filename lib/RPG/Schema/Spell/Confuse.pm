package RPG::Schema::Spell::Confuse;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use Games::Dice::Advanced;

sub _cast {
    my ( $self, $character, $target, $level ) = @_;

    my $defence_modifier = 0 - $level;
    my $duration = 2 * ( int $level / 2 + 1 );

    $self->create_effect(
        {
            target      => $target,
            effect_name    => 'Confused',
            duration       => $duration,
            modifier       => $defence_modifier,
            combat         => 1,
            modified_state => 'defence_factor',
        }
    );

    return {
        type     => 'effect',
        duration => $duration,
        effect   => 'confusing ' . $target->pronoun('objective'),
    };
}

1;
