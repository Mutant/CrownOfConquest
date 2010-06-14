use strict;
use warnings;

package RPG::Schema::Enchantment_Item_Category;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Enchantment_Item_Category');

__PACKAGE__->add_columns(qw/enchantment_id item_category_id/);

__PACKAGE__->set_primary_key(qw/enchantment_id item_category_id/);

__PACKAGE__->belongs_to( 'enchantment', 'RPG::Schema::Enchantments', 'enchantment_id' );
__PACKAGE__->belongs_to( 'category', 'RPG::Schema::Item_Category', 'item_category_id' );

1;