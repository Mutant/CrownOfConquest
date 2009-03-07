use strict;
use warnings;

package Test::RPG::Schema::Character;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use RPG::Schema::Character;

sub test_get_equipped_item : Tests(2) {
	my $self = shift;

	my $super_cat = $self->{schema}->resultset('Super_Category')->create({
		super_category_name => 'Test1',
	});
	
	my $item_cat = $self->{schema}->resultset('Item_Category')->create({
		item_category => 'SubCat1',
		super_category_id => $super_cat->id,
	});
	
	my $ian = $self->{schema}->resultset('Item_Attribute_Name')->create({
		item_attribute_name => 'Test1',
		item_category_id => $item_cat->id,
	});
	
	my $item_type = $self->{schema}->resultset('Item_Type')->create({
		item_type => 'Test1',
		item_category_id => $item_cat->id,
	});
	
	my $ia = $self->{schema}->resultset('Item_Attribute')->create({
		item_attribute_name_id => $ian->id,
		item_attribute_value => 99,
		item_type_id => $item_type->id,
	});

	my $char = $self->{schema}->resultset('Character')->create({
		
	});
	
	my $eq_place = $self->{schema}->resultset('Equip_Places')->find(1);
	
	my $item = $self->{schema}->resultset('Items')->create({
		item_type_id => $item_type->id,
		character_id => $char->id,
		equip_place_id => $eq_place->id,
	});	
	
	
	my ($equipped_item) = $char->get_equipped_item('Test1');
	
	isa_ok($equipped_item, 'RPG::Schema::Items', "Item record returned"); 
	is($equipped_item->id, $item->id, "Correct item returned");
	
	#return;
	$item_cat->delete;
	$ian->delete;
	$item_type->delete;
	$ia->delete;
	$item->delete;	
	$char->delete;
	$super_cat->delete;
	
}

sub test_number_of_attacks : Tests(no_plan) {
	my $self = shift;
	
	my $mock_char = Test::MockObject->new();
	$mock_char->set_always('class',$mock_char);
	$mock_char->set_true('class_name');
	
	
	$mock_char->set_always('effect_value', 0.5);
	is(
		RPG::Schema::Character::number_of_attacks($mock_char, (1,1)),
		2,
		'2 attacks allowed this round because of modifier',
	);
	
	is(
		RPG::Schema::Character::number_of_attacks($mock_char, (1,2)),
		1,
		'1 attacks allowed this round because of history',
	);		
	
	$mock_char->set_always('effect_value', 0.33);
	is(
		RPG::Schema::Character::number_of_attacks($mock_char, (2,1,1)),
		2,
		'2 attacks allowed this round because of modifier',
	);
	
	is(
		RPG::Schema::Character::number_of_attacks($mock_char, (2,1)),
		1,
		'1 attacks allowed this round because of history',
	);
	
	$mock_char->set_always('effect_value', 1);
	is(
		RPG::Schema::Character::number_of_attacks($mock_char, (7,2)),
		2,
		'2 attacks allowed this round because of modifier',
	);
	
	$mock_char->set_always('effect_value', 1.5);
	is(
		RPG::Schema::Character::number_of_attacks($mock_char, (2,2)),
		3,
		'3 attacks allowed this round because of modifier',
	);
	
	is(
		RPG::Schema::Character::number_of_attacks($mock_char, (2,3)),
		2,
		'2 attacks allowed this round because of modifier',
	);
	
	$mock_char->set_always('effect_value', 1.25);
	is(
		RPG::Schema::Character::number_of_attacks($mock_char, (2,3,2,2)),
		2,
		'2 attacks allowed this round because of history',
	);
	
	is(
		RPG::Schema::Character::number_of_attacks($mock_char, (3,2,2,2)),
		3,
		'3 attacks allowed this round because of modifier',
	);
	
	# Test archer's extra attacks
	$mock_char->set_always('class_name', 'Archer');
	my $mock_weapon = Test::MockObject->new();
	$mock_weapon->set_always('item_type', $mock_weapon);
	$mock_weapon->set_always('category', $mock_weapon);
	$mock_weapon->set_always('item_category', 'Ranged Weapon');
	
	$mock_char->set_always('get_equipped_item', $mock_weapon);
	$mock_char->set_always('effect_value', 0);

	is(
		RPG::Schema::Character::number_of_attacks($mock_char),
		1,
		'1 attacks allowed this for an archer',
	);

	is(
		RPG::Schema::Character::number_of_attacks($mock_char, (2)),
		1,
		'1 attacks allowed this for an archer',
	);
	
	is(
		RPG::Schema::Character::number_of_attacks($mock_char, (1)),
		2,
		'2 attacks allowed this for an archer',
	);
}

1;