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
	
	my $item_cat = $self->{schema}->resultset('Item_Category')->create({
		item_category => 'Test1',
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
	
	
	my $equipped_item = $char->_get_equipped_item('Test1');
	
	isa_ok($equipped_item, 'RPG::Schema::Items', "Item record returned"); 
	is($equipped_item->id, $item->id, "Correct item returned");
	
	#return;
	$item_cat->delete;
	$ian->delete;
	$item_type->delete;
	$ia->delete;
	$item->delete;	
	$char->delete;
	
}

1;