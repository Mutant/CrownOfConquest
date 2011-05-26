#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

$schema->storage->txn_begin;

my $jewel_category = $schema->resultset('Item_Category')->find(
    {
        item_category => 'Jewel',
    }
);

my $ivn = $schema->resultset('Item_Variable_Name')->create(
    {
        item_category_id => $jewel_category->id,
        item_variable_name => 'Quantity',
        create_on_insert => 1,
    }
);

foreach my $jewel_type ($jewel_category->item_types) {
    $schema->resultset('Item_Variable_Params')->create(
        {
            item_type_id => $jewel_type->id,
            item_variable_name_id => $ivn->id,
            keep_max => 0,
            min_value => 1,
            max_value => 1,
        }
    );
}

my @items = $schema->resultset('Items')->search(
    {
        'item_type.item_category_id' => $jewel_category->id,
    },
    {
        join => 'item_type',
    }
);

warn scalar @items . " items to update\n";

my $count = 0;
foreach my $item (@items) {
    $item->add_to_item_variables(
        {
            item_variable_value => 1,
            item_variable_name_id => $ivn->id,
        }
    );
    
    $count++;
    if ($count % 100 == 0) {
        warn "Done $count\n";
    }
    
}

$schema->storage->txn_commit;
