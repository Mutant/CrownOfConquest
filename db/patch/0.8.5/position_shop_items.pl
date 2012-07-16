#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use Data::Dumper;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my $shop_id = shift;

my @shops = $schema->resultset('Shop')->search( { status => [qw/Open Closing/] });

foreach my $shop (@shops) {
    next if defined $shop_id && $shop_id != $shop->id;
    warn "Processing shop: " . $shop->id;
    
    $shop->organise;
       
}