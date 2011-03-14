#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( @{$config->{'Model::DBIC'}{connect_info}} );

my $type = shift;
my ($x,$y) = split /,/, shift;

my $building_type = $schema->resultset('Building_Type')->find(
    {
        name => $type,
    }
);

die "No such building type: $type\n" unless $building_type;

my $land = $schema->resultset('Land')->find(
    {
        x => $x,
        y => $y,
    }
);

die "Cannot find sector at $x,$y\n" unless $land;

$schema->resultset('Building')->create(
    {
        land_id => $land->id,
        building_type_id => $building_type->id,
    }
); 