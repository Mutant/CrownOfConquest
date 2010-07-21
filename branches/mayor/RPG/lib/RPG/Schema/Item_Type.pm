package RPG::Schema::Item_Type;
use base 'DBIx::Class';
use strict;
use warnings;

use Carp;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Item_Type');


__PACKAGE__->add_columns(
    'item_type_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 1,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'item_type_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'item_type' => {
      'data_type' => 'varchar',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'item_type',
      'is_nullable' => 0,
      'size' => '255'
    },
    'item_category_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'category_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'base_cost' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'base_cost',
      'is_nullable' => 0,
      'size' => '11'
    },
    'prevalence' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'prevalence',
      'is_nullable' => 0,
      'size' => '11'
    },    
    'weight' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'weight',
      'is_nullable' => 0,
      'size' => '11'
    },      
    'image' => {
      'data_type' => 'varchar',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'image',
      'is_nullable' => 0,
      'size' => '11'
    },    
);
__PACKAGE__->set_primary_key('item_type_id');

__PACKAGE__->belongs_to(
    'category',
    'RPG::Schema::Item_Category',
    { 'foreign.item_category_id' => 'self.item_category_id' }
);

__PACKAGE__->has_many(
    'shops_with_item',
    'RPG::Schema::Items_Made',
    { 'foreign.item_type_id' => 'self.item_type_id' }
);

__PACKAGE__->has_many(
    'item_attributes',
    'RPG::Schema::Item_Attribute',
    { 'foreign.item_type_id' => 'self.item_type_id' }
);

__PACKAGE__->has_many(
    'items',
    'RPG::Schema::Items',
    { 'foreign.item_type_id' => 'self.item_type_id' }
);

__PACKAGE__->many_to_many(
    'shops',
    'RPG::Schema::Shops',
    'shops_with_item',
);

__PACKAGE__->has_many(
    'item_variable_params',
    'RPG::Schema::Item_Variable_Params',
    { 'foreign.item_type_id' => 'self.item_type_id' }
);

sub modified_cost {
	my $self = shift;
	my $shop = shift;

	return $self->base_cost unless $shop;
		
	return int ($self->base_cost / (100 / (100 - $shop->cost_modifier)));	
}

sub attribute {
	my $self = shift;
	my $attribute = shift;

	my @attributes = $self->item_attributes;

	my ($item_attribute) = grep { $_->item_attribute_name->item_attribute_name eq $attribute } @attributes;	
			
	return $item_attribute;
}

sub variable_param {
	my $self = shift;
	my $variable = shift;
	
	my @params = $self->item_variable_params;
	my ($param) = grep { $_->item_variable_name->item_variable_name eq $variable } @params;
	
	return $param;
}

1;