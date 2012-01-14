use strict;
use warnings;

package Test::RPG::Schema::Enchantments::Resistances;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Item;
use Test::RPG::Builder::Character;
use Test::RPG::Builder::Item_Type;

sub test_startup : Tests(startup => 1) {
	my $self = shift;
	
	use_ok('RPG::Schema::Enchantments::Resistances');
}

sub test_setup : Tests(setup) {
	my $self = shift;
	
	$self->{item_type} = Test::RPG::Builder::Item_Type->build_item_type( 
		$self->{schema}, 
		enchantments => [ 'resistances' ],
	);
}

sub test_init : Tests(3) {
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
	cmp_ok($item->variable('Resistance Bonus'), '>=', 1, "Resistance bonus >= 1");
	cmp_ok($item->variable('Resistance Bonus'), '<=', 20, "Resistance bonus <= 20");
	
	is($item->variable('Resistance Type') ~~ [qw/fire ice poison/], 1, "Resistance type in allowed set");
}

sub test_equipping : Tests(2) {
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
	$item->variable('Resistance Bonus', 3);
	$item->variable('Resistance Type', 'ice');
	$item->update;
	
	# WHEN
	$item->character_id($character->id);
	$item->equip_place_id(1);
	$item->update;
	
	# THEN
	$character->discard_changes;
	is($character->resist_ice_bonus, 3, "Resist ice bonus increased");
	is($character->resistance('Ice'), 3, "Resistance to ice calculated correctly");
	
}

1;