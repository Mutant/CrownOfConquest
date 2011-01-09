use strict;
use warnings;

package RPG::Schema::Dungeon_Teleporter;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Dungeon_Teleporter');

__PACKAGE__->add_columns(qw/teleporter_id dungeon_grid_id destination_id invisible/);

__PACKAGE__->set_primary_key('teleporter_id');

__PACKAGE__->belongs_to(
    'dungeon_grid',
    'RPG::Schema::Dungeon_Grid',
    { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' }
);

__PACKAGE__->belongs_to(
    'destination',
    'RPG::Schema::Dungeon_Grid',
    { 'foreign.dungeon_grid_id' => 'self.destination_id' }
);

1;
