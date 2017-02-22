package RPG::Schema::Item_Variable_Params;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Item_Variable_Params');

__PACKAGE__->add_columns(qw/item_variable_param_id keep_max min_value max_value item_type_id item_variable_name_id special/);
__PACKAGE__->set_primary_key('item_variable_param_id');

__PACKAGE__->belongs_to(
    'item_variable_name',
    'RPG::Schema::Item_Variable_Name',
    { 'foreign.item_variable_name_id' => 'self.item_variable_name_id' }
);

1;
