#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

use Games::Dice::Advanced;

die "RPG_HOME not set\n" unless $ENV{RPG_HOME};

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( @{$config->{'Model::DBIC'}{connect_info}} );

my @terrain = $schema->resultset('Terrain')->search;

foreach my $terrain (@terrain) {
    my $terrain_name = $terrain->terrain_name;
    $terrain_name =~ s/ /_/g;
    
    my @v = glob($ENV{RPG_HOME} . "/docroot/static/images/map/$terrain_name*");
    my $variations = scalar @v;
        
    next if scalar $variations <= 1;
    
    my @land = $schema->resultset('Land')->search(
        {
            terrain_id => $terrain->id,
        }
    );
    
    foreach my $land (@land) {
        my $variation = Games::Dice::Advanced->roll('1d' . $variations);
        $land->variation($variation);
        $land->update;   
    }
}