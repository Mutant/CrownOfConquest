use strict;
use warnings;

use Test::More 'no_plan';
use Test::Exception;

use RPG::Schema;

ok(sub {RPG::Schema->resultset('Shop')->find(1)}, "dies if there's no connection");

my $schema = RPG::Schema->connect(
    "dbi:mysql:game",
    "root",
    "",
    { AutoCommit => 1 },
);

$schema->storage->debug(1);

my $shop;
ok($shop = $schema->resultset('Shop')->find(1), "finds a shop");

is($shop->id, 1);

my @items;
ok(@items = $shop->items_in_shop, "gets list of items in the shop");

ok($shop = $schema->resultset('Shop')->search(
    {
        shop_id => 1,
    },
), "Search for a shop");

is($shop->first->id, 1);

my $item;
ok($item = $schema->resultset('Item_Type')->search(
    {
        'shop.shop_id' => 1,
    },
    {
        join => {'shops_with_item' => 'shop'},
    }
), "Search for item_type with shop criteria");

is($item->first->id, 1);