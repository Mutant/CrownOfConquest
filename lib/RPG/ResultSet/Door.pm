use strict;
use warnings;

package RPG::ResultSet::Door;

use base 'DBIx::Class::ResultSet';

use Carp;

sub get_secret_doors_in_room {
    my $self = shift;

    my $dungeon_room_id = shift || croak "Dungeon room id not supplied";

    return $self->search(
        {
            'type'                         => 'secret',
            'state'                        => 'closed',
            'dungeon_room.dungeon_room_id' => $dungeon_room_id,
        },
        {
            join => { 'dungeon_grid' => 'dungeon_room' },
            prefetch => 'position',
        },
    );
}

1;
