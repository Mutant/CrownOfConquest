package RPG::Schema::Item_Category;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Item_Category');


__PACKAGE__->add_columns(
    'item_category_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 1,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'category_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'item_category' => {
      'data_type' => 'varchar',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'category_name',
      'is_nullable' => 0,
      'size' => '255'
    },
);
__PACKAGE__->set_primary_key('item_category_id');

__PACKAGE__->has_many(
    'item_types',
    'RPG::Schema::Item_Type',
    { 'foreign.item_category_id' => 'self.item_category_id' }
);

1;