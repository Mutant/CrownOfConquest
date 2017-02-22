use strict;
use warnings;

package RPG::Schema::Dungeon_Position;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Dungeon_Position');

__PACKAGE__->add_columns(qw/position_id position/);

__PACKAGE__->set_primary_key('position_id');

1;
