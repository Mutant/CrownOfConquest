use strict;
use warnings;

package Test::RPG::Schema::Shop;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use RPG::Schema::Shop;

sub test_schema_setup : Tests(7) {
	my $self = shift;
	
	return "Skipped for now to removed DB stuff.. need proper test DB setup";
	
	my $shop;
	ok($shop = $self->{schema}->resultset('Shop')->find(1), "finds a shop");
	
	is($shop->id, 1);
	
	my @items;
	ok(@items = $shop->items_in_shop, "gets list of items in the shop");
	
	ok($shop = $self->{schema}->resultset('Shop')->search(
	    {
	        shop_id => 1,
	    },
	), "Search for a shop");
	
	is($shop->first->id, 1);
	
	my $item;
	ok($item = $self->{schema}->resultset('Item_Type')->search(
	    {
	        'shop.shop_id' => 1,
	    },
	    {
	        join => {'shops_with_item' => 'shop'},
	    }
	), "Search for item_type with shop criteria");
	
	is($item->first->id, 1);
}

1;