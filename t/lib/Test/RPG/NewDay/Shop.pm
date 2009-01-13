use strict;
use warnings;

package Test::RPG::NewDay::Shop;

use base qw(Test::RPG);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

sub startup : Test(startup => 1) {
	my $self = shift;
	
	use_ok 'RPG::NewDay::Shop';
	
}

sub test_alter_statuses_of_shops : Tests(8) {
	my $mock_shop = Test::MockObject->new();
	$mock_shop->set_true('status');
	$mock_shop->set_true('update');
	
	my $left = RPG::NewDay::Shop::_alter_statuses_of_shops(
		number_to_change => 1,
		open_or_close => 'Open',
		shops_by_status => {
			Opening => [$mock_shop],
		},
	);
	
	is($left, 0, "No shops left to open");
	my ($method, $args);
	($method, $args) = $mock_shop->next_call();
	is($method, 'status', "Status called");
	is($args->[1], 'Open', "Shop opened");
	
	($method, $args) = $mock_shop->next_call();
	is($method, 'update', "Update called");

	$mock_shop->clear();
	
	$left = RPG::NewDay::Shop::_alter_statuses_of_shops(
		number_to_change => 2,
		open_or_close => 'Close',
		shops_by_status => {
			Opening => [$mock_shop],
		},
	);
		
	is($left, 1, "One shop left to change");	
	($method, $args) = $mock_shop->next_call();
	is($method, 'status', "Status called");
	is($args->[1], 'Closing', "Shop opened");
	
	($method, $args) = $mock_shop->next_call();
	is($method, 'update', "Update called");
		
}