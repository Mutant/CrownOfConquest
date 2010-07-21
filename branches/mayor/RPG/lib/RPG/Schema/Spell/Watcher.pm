package RPG::Schema::Spell::Watcher;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use Games::Dice::Advanced;

sub _cast {
    my ( $self, $character, $target, $level ) = @_;

    my $duration = 2 * ( int $level / 3 + 1 );

    $self->create_party_effect(
        {
            target      => $target,
            effect_name => 'Watcher',
            duration    => $duration,
            combat      => 0,
            time_type   => 'day',
        }
    );

    return {
        type      => 'party_effect',
        duration  => $duration,
        effect    => 'watching the party',
        time_type => 'day',
    };
}

1;
