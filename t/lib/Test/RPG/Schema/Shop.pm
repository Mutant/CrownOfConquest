use strict;
use warnings;

package Test::RPG::Schema::Shop;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Shop;
use Test::RPG::Builder::Item;

use RPG::Schema::Shop;

sub test_grouped_items_in_shop : Tests {
    my $self = shift;
    
    # GIVEN
    my $shop = Test::RPG::Builder::Shop->build_shop($self->{schema});
    my $item = Test::RPG::Builder::Item->build_item($self->{schema});
    $item->shop_id($shop->id);
    $item->update;
    
    # WHEN
    my @grouped_items = $shop->grouped_items_in_shop;
    
    # THEN
    is(scalar @grouped_items, 1, "One item returned");
       
}

1;