use strict;
use warnings;

package RPG::Schema::Dungeon;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Dungeon');

__PACKAGE__->add_columns(qw/dungeon_id level land_id name/);

__PACKAGE__->set_primary_key('dungeon_id');

__PACKAGE__->has_many(
    'sectors',
    'RPG::Schema::Dungeon_Grid',
    { 'foreign.dungeon_id' => 'self.dungeon_id' }
);

1;