package RPG::Schema::Item_Attribute_Name;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Item_Attribute_Name');

__PACKAGE__->add_columns(qw/item_attribute_name_id item_attribute_name item_category_id/);
__PACKAGE__->set_primary_key('item_attribute_name_id');

1;