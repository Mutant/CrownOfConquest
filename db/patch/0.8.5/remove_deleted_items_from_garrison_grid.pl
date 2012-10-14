#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use Data::Dumper;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @garrisons = $schema->resultset('Garrison')->search(
    {
        land_id => {'!=', undef},
    }
);

foreach my $garrison (@garrisons) {
  
    my @in_grid = $garrison->search_related('item_sectors',
        {
            start_sector => 1,
        },
    );
    
    foreach my $in_grid (@in_grid) {
        my $item = $garrison->find_related('items',
            {
                item_id => $in_grid->item_id,
            },
        );
        
        if (! $item) {
            print "Item " . $in_grid->item_id . " is in garrisons's grid but does not exist, removing\n";
        	$garrison->search_related('item_sectors',
        	   {
        	       item_id => $in_grid->item_id ,
        	   }
            )->update( { item_id => undef, start_sector => undef, } );               
        }
    }
}