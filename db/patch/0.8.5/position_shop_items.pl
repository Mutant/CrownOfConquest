#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use Data::Dumper;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my $shop_id = shift;

my @shops = $schema->resultset('Shop')->search;

foreach my $shop (@shops) {
    next if defined $shop_id && $shop_id != $shop->id;
    warn "Processing shop: " . $shop->id;
    
    for my $x (1..12) {
        for my $y (1..8) {
            my $sector = $schema->resultset('Item_Grid')->find_or_create(
                {
                    owner_id => $shop->id,
                    owner_type => 'shop',
                    x => $x,
                    y => $y,
                }
            );
            $sector->item_id(undef);
            $sector->start_sector(undef);
            $sector->update;
        }
    }
    
    $shop->organise_items;
       
}