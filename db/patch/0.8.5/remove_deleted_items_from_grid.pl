#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use Data::Dumper;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @chars = $schema->resultset('Character')->search();

foreach my $character (@chars) {
  
    my @in_grid = $character->search_related('item_sectors',
        {
            start_sector => 1,
        },
    );
    
    foreach my $in_grid (@in_grid) {
        my $item = $character->find_related('items',
            {
                item_id => $in_grid->item_id,
            },
        );
        
        if (! $item) {
            print "Item " . $in_grid->item_id . " is in char's grid but does not exist\n";    
        }
    }
}