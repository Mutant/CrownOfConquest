#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use Data::Dumper;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @items = $schema->resultset('Items')->search(
    {
        'category.always_enchanted' => 1,
    },
    {
        join => {'item_type' => 'category'},
    },
);

foreach my $item (@items) {
    if ($item->enchantments_count <= 0) {
        $item->delete;
    }
} 