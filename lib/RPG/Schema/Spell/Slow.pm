package RPG::Schema::Spell::Slow;

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
            effect_name    => 'Slowed',
            duration       => $duration,
            modifier       => 1,
            combat         => 1,
            modified_state => 'attack_frequency',
        }
    );
    
    return {
        type => 'effect',
        duration   => $duration,
        effect     => 'slowing ' . $target->pronoun('objective'),
    };
}

1;
