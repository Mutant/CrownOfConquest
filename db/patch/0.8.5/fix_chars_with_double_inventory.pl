#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use Data::Dumper;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @chars = $schema->resultset('Character')->search();

foreach my $char (@chars) {
    next if $char->item_sectors->count == 64;
    
    $char->item_sectors->delete;
    
    $char->create_grid('character', 8, 8);
    
    $char->organise_items; 
}