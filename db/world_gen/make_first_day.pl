#!/usr/bin/perl

use strict;
use warnings;

use lib "$ENV{RPG_HOME}/lib";

use RPG::Schema;
use RPG::LoadConf;
use DateTime;
use FindBin;

my $config = RPG::LoadConf->load($FindBin::Bin . '/world_gen.yml');

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

$schema->resultset('Day')->create(
    {
        day_number => 1,
        game_year => 100,
        date_started => DateTime->now(),
    }
);