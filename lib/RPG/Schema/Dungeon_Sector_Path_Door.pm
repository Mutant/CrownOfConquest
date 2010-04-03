use strict;
use warnings;

package RPG::Schema::Dungeon_Sector_Path_Door;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Dungeon_Sector_Path_Door');

__PACKAGE__->add_columns(qw/sector_id has_path_to door_id/);

__PACKAGE__->set_primary_key('sector_id', 'has_path_to', 'door_id');

1;