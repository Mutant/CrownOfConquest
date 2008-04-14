package RPG::Schema::Item_Attribute;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Item_Attribute');

__PACKAGE__->add_columns(qw/item_attribute_id item_attribute_name_id item_attribute_value item_type_id/);
__PACKAGE__->set_primary_key('item_attribute_id');

__PACKAGE__->belongs_to(
    'item_type',
    'RPG::Schema::Item_Type',
    { 'foreign.item_type_id' => 'self.item_type_id' }
);

__PACKAGE__->belongs_to(
    'item_attribute_name',
    'RPG::Schema::Item_Attribute_Name',
    { 'foreign.item_attribute_name_id' => 'self.item_attribute_name_id' }
);

1;