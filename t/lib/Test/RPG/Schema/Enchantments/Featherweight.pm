use strict;
use warnings;

package Test::RPG::Schema::Enchantments::Featherweight;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Item;
use Test::RPG::Builder::Character;
use Test::RPG::Builder::Item_Type;

sub test_startup : Tests(startup => 1) {
	my $self = shift;
	
	use_ok('RPG::Schema::Enchantments::Featherweight');
}

sub test_setup : Tests(setup) {
	my $self = shift;
	
	$self->{item_type} = Test::RPG::Builder::Item_Type->build_item_type( 
		$self->{schema}, 
		enchantments => [ 'featherweight' ],
		weight => 100, 
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
	my @enchantments = $item->item_enchantments;
	is(scalar @enchantments, 1, "One enchantment on item");
	cmp_ok($item->weight, '<', 100, "Item is lighter than normal");
	cmp_ok($item->weight, '>=', 50, "Item is not lighter than the max");
	
}

1;