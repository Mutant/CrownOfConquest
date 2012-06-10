package RPG::Schema::Spell::Portal;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use Games::Dice::Advanced;

sub _cast {
    my ( $self, $character, $target, $level ) = @_;

    # Check if they're pending mayor, and clear it if they are
    my $dungeon = $target->dungeon_grid->dungeon_room->dungeon;
    
    if ($dungeon->type eq 'castle') {
        my $town = $dungeon->town;
        
        if ($town->pending_mayor == $target->id) {
            $town->decline_mayoralty;
            $town->update;
        }
    }

    $target->dungeon_grid_id(undef);
    $target->update;
    
    return {
        type   => 'portal',
        custom => {
            raid_ended => $dungeon->type eq 'castle' ? 1 : 0,
            castle => $dungeon,
        },
    };
}

sub can_cast {
	my $self = shift;
	my $character = shift;
	
	return $character->party->dungeon_grid_id ? 1 : 0;
}

1;
