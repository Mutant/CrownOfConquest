#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use List::Util qw(shuffle);

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( @{$config->{'Model::DBIC'}{connect_info}} );

my @terrain = ('mountain', 'medium forest', 'field');

my @sectors = $schema->resultset('Land')->search(
    {
        'terrain.terrain_name' => {'!=', \@terrain},
        'tileset_id' => 3,
    },
    {
        join => 'terrain',
    }
);

foreach my $sector (@sectors) {
    my $terrain_type = (shuffle @terrain)[0];
    my $terrain_rec = $schema->resultset('Terrain')->find({ terrain_name => $terrain_type });
    die "couldn't find rec for $terrain_type" unless $terrain_rec;
    $sector->terrain_id($terrain_rec->id);
    $sector->variation(1);
    $sector->update;   
}