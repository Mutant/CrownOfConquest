package RPG::Schema::Spell::Blades;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use Games::Dice::Advanced;

sub _cast {
    my ( $self, $character, $target ) = @_;

    my $modifier = $character->level;
    my $duration = 2 + ( int $character->level / 3 + 1 );

    $self->create_effect(
        {
            target_type    => 'character',
            target_id      => $target->id,
            effect_name    => 'Blades',
            duration       => $duration,
            modifier       => $modifier,
            combat         => 1,
            modified_state => 'damage',
        }
    );

    return {
        type     => 'effect',
        duration => $duration,
        effect   => 'enhancing his weapon',
    };
}

1;