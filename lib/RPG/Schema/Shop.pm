package RPG::Schema::Shop;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Shop');


__PACKAGE__->add_columns(
    'shop_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 1,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'shop_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'shop_name' => {
      'data_type' => 'varchar',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'shop_name',
      'is_nullable' => 0,
      'size' => '255'
    },
    'land_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 1,
      'name' => 'land_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'cost_modifier' => {
      'data_type' => 'float',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'cost_modifier',
      'is_nullable' => 0,
      'size' => '11'
    },
);
__PACKAGE__->set_primary_key('shop_id');

__PACKAGE__->has_many(
    'items_in_shop',
    'RPG::Schema::Items_In_Shop',
    { 'foreign.shop_id' => 'self.shop_id' }
);

__PACKAGE__->many_to_many(
    'item_types',
    'RPG::Schema::Items_Type',
    'items_in_shop',
);

1;