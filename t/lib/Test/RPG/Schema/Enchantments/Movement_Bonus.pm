use strict;
use warnings;

package Test::RPG::Schema::Enchantments::Movement_Bonus;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Item;
use Test::RPG::Builder::Character;
use Test::RPG::Builder::Item_Type;

sub test_startup : Tests(startup => 1) {
	my $self = shift;
	
	use_ok('RPG::Schema::Enchantments::Movement_Bonus');
}

sub test_setup : Tests(setup) {
	my $self = shift;
	
	$self->{item_type} = Test::RPG::Builder::Item_Type->build_item_type( 
		$self->{schema}, 
		enchantments => [ 'movement_bonus' ],
	);
}

sub test_init : Tests(2) {
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
	cmp_ok($item->variable('Movement Bonus'), '>=', 1, "Movement bonus >= 1");
	cmp_ok($item->variable('Movement Bonus'), '<=', 5, "Movement bonus <= 5");
}

sub test_equipping : Tests(1) {
	my $self = shift;	
	
	# GIVEN
	my $character = Test::RPG::Builder::Character->build_character($self->{schema}, constitution => 20);

	my $item = $self->{schema}->resultset('Items')->create_enchanted(
		{
			item_type_id => $self->{item_type}->id,
		},
		{
			number_of_enchantments => 1,
		},
	);	
	$item->variable('Movement Bonus', 3);
	$item->update;
	
	# WHEN
	$item->character_id($character->id);
	$item->equip_place_id(1);
	$item->update;
	
	# THEN
	$character->discard_changes;
	is($character->natural_movement_factor, 8, "Character's movement factor increased");
	
}

1;