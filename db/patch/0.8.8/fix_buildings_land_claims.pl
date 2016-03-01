#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( @{$config->{'Model::DBIC'}{connect_info}} );

my @buildings = $schema->resultset('Building')->search(
    {
        'owner_type' => 'kingdom',
        'location.claimed_by_type' => [ undef, {'!=','building'}],
    },
    {
        prefetch => 'location',
    }
);

foreach my $building (@buildings) {
    my $garrison = $building->location->garrison;
    if ($garrison) {
        $garrison->unclaim_land;
    }
    $building->unclaim_land;
    $building->claim_land;    
}