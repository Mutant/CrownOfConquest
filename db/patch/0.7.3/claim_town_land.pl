#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use RPG::Map;
use RPG::ResultSet::RowsInSectorRange;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @towns = $schema->resultset('Town')->search(
    {},
    {
        prefetch => 'location',
    },
);

foreach my $town (@towns) {
    $town->claim_land;
}

my @buildings = $schema->resultset('Building')->search(
    {},
    {
        prefetch => 'location',
    },
);

foreach my $building (@buildings) {
    $building->claim_land;   
}
