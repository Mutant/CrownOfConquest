use strict;
use warnings;

package Test::RPG::Schema::Enchantments::Indestructible;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Item;
use Test::RPG::Builder::Character;
use Test::RPG::Builder::Item_Type;

sub test_startup : Tests(startup => 1) {
	my $self = shift;
	
	use_ok('RPG::Schema::Enchantments::Indestructible');
}

sub test_setup : Tests(setup) {
	my $self = shift;
	
	$self->{item_type} = Test::RPG::Builder::Item_Type->build_item_type( 
		$self->{schema}, 
		enchantments => [ 'indestructible' ],
		variables => [
			{
				name => 'Durability',
				create_on_insert => 1,
				keep_max => 1,
				min_value => 10,
				max_value => 10,
			},
		],
		attributes => [
			{
				item_attribute_name => 'Defence Factor',
				item_attribute_value => 10,
			}			
		], 
	);
	
	my $eq_place = $self->{schema}->resultset('Equip_Places')->find(
		{
			equip_place_name => 'Head',
		}
	);
	
	$self->{schema}->resultset('Equip_Place_Category')->create(
		{
			equip_place_id => $eq_place->id,
			item_category_id => $self->{item_type}->item_category_id,
		}
	);
		
}

sub test_init : Tests(1) {
	my $self = shift;
	
	# GIVEN
	
	# WHEN
	my $item = $self->{schema}->resultset('Items')->create_enchanted(
		{
			item_type_id => $self->{item_type}->id,
		},
		{
			number_of_enchantments => 1,
		},
	);
	
	# THEN
	is($item->variable('Durability'), undef, "Item has no durability");
}

sub test_indestructible_armour : Tests(2) {
	my $self = shift;
	
	# GIVEN
	my $super_cat = $self->{item_type}->category->super_category;
	$super_cat->super_category_name('Armour');
	$super_cat->update;
	
	my $character = Test::RPG::Builder::Character->build_character($self->{schema}, agility => 10);
	
	my $item = $self->{schema}->resultset('Items')->create_enchanted(
		{
			item_type_id => $self->{item_type}->id,
		},
		{
			number_of_enchantments => 1,
		},
	);
	
	$item->add_to_characters_inventory($character);	
	
	# WHEN
	my $df = $character->defence_factor;
	my $exe_result = $character->execute_defence;
	
	# THEN
	is($df, 20, "Indestructible item included in defence factor, even though it has no durability");
	is($exe_result, undef, "Armour not considered broken");	
}


