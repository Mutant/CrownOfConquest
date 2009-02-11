use strict;
use warnings;

package RPG::Schema::Dungeon_Wall;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Dungeon_Wall');

__PACKAGE__->add_columns(qw/wall_id dungeon_grid_id position_id/);

__PACKAGE__->set_primary_key('wall_id');

__PACKAGE__->belongs_to(
    'position',
    'RPG::Schema::Dungeon_Position',
    { 'foreign.position_id' => 'self.position_id' }
);

1;