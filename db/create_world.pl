#!/usr/bin/perl
# Script to create a new world
#  See world_gen/README

use strict;
use warnings;
use autodie;

use lib "$ENV{RPG_HOME}/lib";

use RPG::Schema;
use RPG::LoadConf;
use DateTime;
use FindBin;

my $config = RPG::LoadConf->load($FindBin::Bin . '/world_gen/world_gen.yml');

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

# Check we're connecting to a clean DB
my @rs_to_check = qw(
    Land
    Town
    Dungeon
    Kingdom
);

foreach my $rs (@rs_to_check) {
    if ($schema->resultset($rs)->search->count > 0) {
        die "Already $rs in this DB, not continuing\n";
    }
}

# Create land
system($FindBin::Bin . '/world_gen/make_land.pl');

# Create towns
system($FindBin::Bin . '/world_gen/make_towns.pl');

# Create roads
system($FindBin::Bin . '/world_gen/make_roads.pl');

# Create first day
system($FindBin::Bin . '/world_gen/make_first_day.pl');

# Create kingdoms
system($FindBin::Bin . '/world_gen/make_kingdoms.pl');

# Init world
system($FindBin::Bin . '/world_gen/init_world.pl');
