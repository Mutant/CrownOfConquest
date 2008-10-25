package RPG::Schema::Item_Category;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Item_Category');

__PACKAGE__->add_columns(qw/item_category_id item_category super_category_id hidden auto_add_to_shop/);
__PACKAGE__->set_primary_key('item_category_id');

__PACKAGE__->has_many(
    'item_types',
    'RPG::Schema::Item_Type',
    { 'foreign.item_category_id' => 'self.item_category_id' }
);

__PACKAGE__->has_many(
    'item_attribute_names',
    'RPG::Schema::Item_Attribute_Name',
    { 'foreign.item_category_id' => 'self.item_category_id' }
);

__PACKAGE__->has_many(
    'item_variable_names',
    'RPG::Schema::Item_Variable_Name',
    { 'foreign.item_category_id' => 'self.item_category_id' }
);

__PACKAGE__->belongs_to(
    'super_category',
    'RPG::Schema::Super_Category',
    { 'foreign.super_category_id' => 'self.super_category_id' }
);

1;