package RPG::Schema::Dungeon_Special_Room;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Dungeon_Special_Room');

__PACKAGE__->add_columns(qw/special_room_id room_type/);

__PACKAGE__->set_primary_key('special_room_id');

1;