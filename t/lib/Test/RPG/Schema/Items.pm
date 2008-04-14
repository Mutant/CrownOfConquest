use strict;
use warnings;

package Test::RPG::Schema::Items;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use RPG::Schema::Items;

sub test_attribute : Tests(1) {
	my $self = shift;
	
	my $ian = $self->{schema}->resultset('Item_Attribute_Name')->create({
		item_attribute_name => 'Test1',
		item_category_id => 1,
	});
	
	my $item_type = $self->{schema}->resultset('Item_Type')->create({
		item_type => 'Test1',
		item_category_id => 1,
	});
	
	my $ia = $self->{schema}->resultset('Item_Attribute')->create({
		item_attribute_name_id => $ian->id,
		item_attribute_value => 99,
		item_type_id => $item_type->id,
	});
	
	my $item = $self->{schema}->resultset('Items')->create({
		item_type_id => $item_type->id,
	});
	
	is($item->attribute('Test1'), 99, "Item attribute value returned");
	
	$ian->delete;
	$item_type->delete;
	$ia->delete;
	$item->delete;
}

1;