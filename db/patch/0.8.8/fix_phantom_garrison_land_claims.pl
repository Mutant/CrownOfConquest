#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( @{$config->{'Model::DBIC'}{connect_info}} );

my @land = $schema->resultset('Land')->search(
    {
        'claimed_by_type' => 'garrison',
    },
);

foreach my $land (@land) {    
    my $garrison = $schema->resultset('Garrison')->find({
        garrison_id => $land->claimed_by_id,
    });        
    
    if (! $garrison || ! $garrison->land_id) {
        $land->claimed_by_type(undef);
        $land->claimed_by_id(undef);
        $land->update;    
    }    
}

my @buildings = $schema->resultset('Building')->search();

foreach my $building (@buildings) {
    $building->unclaim_land;
    $building->claim_land;    
}