use strict;
use warnings;

package RPG::Schema::Enchantments;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Enchantments');

__PACKAGE__->resultset_class('RPG::ResultSet::Enchantments');

__PACKAGE__->add_columns(qw/enchantment_id enchantment_name/);

__PACKAGE__->set_primary_key('enchantment_id');

__PACKAGE__->has_many( 'item_enchantments', 'RPG::Schema::Item_Enchantments', 'enchantment_id' );

1;