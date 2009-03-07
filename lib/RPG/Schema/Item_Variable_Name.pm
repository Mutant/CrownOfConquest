package RPG::Schema::Item_Variable_Name;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Item_Variable_Name');

__PACKAGE__->add_columns(qw/item_variable_name_id item_category_id item_variable_name property_category_id/);
__PACKAGE__->set_primary_key('item_variable_name_id');

__PACKAGE__->belongs_to(
    'property_category',
    'RPG::Schema::Item_Property_Category',
    { 'foreign.property_category_id' => 'self.property_category_id' }
);

__PACKAGE__->belongs_to(
    'item_category',
    'RPG::Schema::Item_Category',
    { 'foreign.item_category_id' => 'self.item_category_id' }
);


1;