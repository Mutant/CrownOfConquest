package RPG::Schema::Item_Variable;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Item_Variable');

__PACKAGE__->add_columns(qw/item_variable_name item_variable_id item_variable_value item_id/);
__PACKAGE__->set_primary_key('item_variable_name');

1;