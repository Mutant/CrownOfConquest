package RPG::Schema::Spell::Bless;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use Games::Dice::Advanced;

sub _cast {
    my ( $self, $character, $target ) = @_;

    my $modifier = $character->level;
    my $duration = 1 + ( int $character->level / 3 + 1 );

    $self->create_effect(
        {
            target_type    => 'character',
            target_id      => $target->id,
            effect_name    => 'Bless',
            duration       => $duration,
            modifier       => $modifier,
            combat         => 1,
            modified_state => 'attack_factor',
        }
    );

    return {
        type     => 'effect',
        duration => $duration,
        effect   => 'blessing',
    };
}

1;
