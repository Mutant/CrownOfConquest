use strict;
use warnings;

package RPG::Schema::Dungeon_Room;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Dungeon_Room');

__PACKAGE__->add_columns(qw/dungeon_room_id dungeon_id/);

__PACKAGE__->set_primary_key('dungeon_room_id');

__PACKAGE__->belongs_to(
    'dungeon',
    'RPG::Schema::Dungeon',
    { 'foreign.dungeon_id' => 'self.dungeon_id' }
);

1;