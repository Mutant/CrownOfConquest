#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @towns = $schema->resultset('Town')->search(
    {},
    {
        prefetch => 'location',
    },
);

foreach my $town (@towns) {
    $town->unclaim_land;
    $town->claim_land;
}

