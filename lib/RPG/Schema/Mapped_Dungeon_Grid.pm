use strict;
use warnings;

package RPG::Schema::Mapped_Dungeon_Grid;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Mapped_Dungeon_Grid');

__PACKAGE__->add_columns(qw/mapped_grid_id party_id dungeon_grid_id date_mapped/);

__PACKAGE__->set_primary_key('mapped_grid_id');

__PACKAGE__->belongs_to(
    'dungeon_grid',
    'RPG::Schema::Dungeon_Grid',
    { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' }
);

1;