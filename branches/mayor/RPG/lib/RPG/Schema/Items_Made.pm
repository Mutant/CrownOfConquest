package RPG::Schema::Items_Made;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Items_Made');


__PACKAGE__->add_columns(
    'shop_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => undef,
      'is_foreign_key' => 1,
      'name' => 'shop_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'item_type_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'item_type_id',
      'is_nullable' => 0,
      'size' => '255'
    },
);
__PACKAGE__->set_primary_key(qw/shop_id item_type_id/);

__PACKAGE__->belongs_to(
    'shop',
    'RPG::Schema::Shop',
    { 'foreign.shop_id' => 'self.shop_id' }
);

__PACKAGE__->belongs_to(
    'item_type',
    'RPG::Schema::Item_Type',
    { 'foreign.item_type_id' => 'self.item_type_id' }
);

1;