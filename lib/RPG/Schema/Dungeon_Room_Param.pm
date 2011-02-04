package RPG::Schema::Dungeon_Room_Param;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Dungeon_Room_Param');

__PACKAGE__->add_columns(qw/dungeon_room_param_id param_name param_value/);

__PACKAGE__->set_primary_key('dungeon_room_param_id');

1;