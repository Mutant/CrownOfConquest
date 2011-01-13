package RPG::Schema::Building_Type;
use base 'DBIx::Class';
use strict;
use warnings;

use Carp;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Building_Type');


__PACKAGE__->add_columns(
    'building_type_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 1,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'building_type_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'name' => {
      'data_type' => 'varchar',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'name',
      'is_nullable' => 0,
      'size' => '100'
    },
    'class' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'class',
      'is_nullable' => 0,
      'size' => '11'
    },
    'level' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'level',
      'is_nullable' => 0,
      'size' => '11'
    },
    'defense_factor' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'defense_factor',
      'is_nullable' => 0,
      'size' => '11'
    },
    'attack_factor' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'attack_factor',
      'is_nullable' => 0,
      'size' => '11'
    },
    'heal_factor' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'heal_factor',
      'is_nullable' => 0,
      'size' => '11'
    },
    'commerce_factor' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'commerce_factor',
      'is_nullable' => 0,
      'size' => '11'
    },
    'clay_needed' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'clay_needed',
      'is_nullable' => 0,
      'size' => '11'
    },
    'stone_needed' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'stone_needed',
      'is_nullable' => 0,
      'size' => '11'
    },
    'wood_needed' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'wood_needed',
      'is_nullable' => 0,
      'size' => '11'
    },
    'iron_needed' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'iron_needed',
      'is_nullable' => 0,
      'size' => '11'
    },
    'labor_needed' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'labor_needed',
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
    'constr_image' => {
      'data_type' => 'varchar',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'constr_image',
      'is_nullable' => 0,
      'size' => '11'
    },    
);
__PACKAGE__->set_primary_key('building_type_id');

#__PACKAGE__->belongs_to(
#    'category',
#    'RPG::Schema::Item_Category',
#    { 'foreign.item_category_id' => 'self.item_category_id' }
#);
#
#__PACKAGE__->many_to_many(
#    'shops',
#    'RPG::Schema::Shops',
#    'shops_with_item',
#);
#
#__PACKAGE__->has_many(
#    'item_variable_params',
#    'RPG::Schema::Item_Variable_Params',
#    { 'foreign.item_type_id' => 'self.item_type_id' }
#);

sub modified_cost {
	my $self = shift;
	my $shop = shift;
	
	my $base_cost = $self->base_cost;
	
	$base_cost = 1 if $base_cost < 1;

	return $base_cost unless $shop;
	
	my $town = $shop->in_town;
	my $sales_tax = $town->mayor && $town->mayor->party_id ? $town->sales_tax : RPG::Schema->config->{default_sales_tax};
		
	my $modified_cost = int ($self->base_cost + ($self->base_cost * ($sales_tax / 100))); 
	
	$modified_cost = 1 if $modified_cost < 1;	
	
	return $modified_cost;
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
