package RPG::Schema::Items;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Items');


__PACKAGE__->add_columns(
    'item_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 1,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'item_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'item_type_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 1,
      'name' => 'item_type_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'magic_modifier' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'magic_modifier',
      'is_nullable' => 0,
      'size' => '11'
    },
    'name' => {
      'data_type' => 'varchar',
      'is_auto_increment' => 0,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'name',
      'is_nullable' => 1,
      'size' => '255'
    },    
    'character_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'character_id',
      'is_nullable' => 1,
      'size' => '11'
    },
    'shop_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'shop_id',
      'is_nullable' => 0,
      'size' => '11'
    },    
    
);
__PACKAGE__->set_primary_key('item_id');

__PACKAGE__->belongs_to(
    'item_type',
    'RPG::Schema::Item_Type',
    { 'foreign.item_type_id' => 'self.item_type_id' }
);

__PACKAGE__->belongs_to(
    'in_shop',
    'RPG::Schema::Shop',
    { 'foreign.shop_id' => 'self.shop_id' }
);


sub modified_cost {
	my $self = shift;
	my $type = shift;
	my $shop = shift;
	
	$type ||= $self->item_type;
	
	return $type->base_cost unless $self->shop_id;
	
	$shop ||= $self->in_shop;
	
	return int ($type->base_cost / (100 / (100 + $shop->cost_modifier)));	
}

1;