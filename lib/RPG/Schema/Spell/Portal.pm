package RPG::Schema::Spell::Portal;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use Games::Dice::Advanced;

sub _cast {
    my ( $self, $character, $target, $level ) = @_;

    $target->dungeon_grid_id(undef);
    $target->update;

    return {
        type   => 'portal',
    };
}

sub can_cast {
	my $self = shift;
	my $character = shift;
	
	return $character->party->dungeon_grid_id ? 1 : 0;	
}

1;
