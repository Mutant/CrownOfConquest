package RPG::Schema::Spell::Shield;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use Games::Dice::Advanced;
use Math::Round qw(round);

sub _cast {
    my ( $self, $character, $target, $level ) = @_;

    my $shield_modifier = round $level / 2;
    $shield_modifier = 5 if $shield_modifier < 5;
    my $duration = 2 * ( int $level / 5 + 1 );

    $self->create_effect(
        {
            target      => $target,
            effect_name    => 'Shield',
            duration       => $duration,
            modifier       => $shield_modifier,
            combat         => 1,
            modified_state => 'defence_factor',
        }
    );

    return {
        type     => 'effect',
        duration => $duration,
        effect   => 'protecting ' . $target->pronoun('objective'),
    };
}

1;
