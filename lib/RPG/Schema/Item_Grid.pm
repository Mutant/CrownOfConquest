use strict;
use warnings;

package RPG::Schema::Item_Grid;

use base 'DBIx::Class';

use Moose;

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Item_Grid');

__PACKAGE__->add_columns(qw/item_grid_id owner_id owner_type item_id start_sector tab x y/);

__PACKAGE__->set_primary_key(qw/item_grid_id/);

__PACKAGE__->belongs_to( 'item', 'RPG::Schema::Items', 'item_id' );

1;