#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @buildings = $schema->resultset('Building')->search(
    {
        owner_type => 'kingdom',
    },
);

foreach my $building (@buildings) {
    $building->claim_land;
}