#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

use RPG::Schema::Dungeon;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @kingdoms = $schema->resultset('Kingdom')->search(
    {
        highest_town_count_day_id => 0,
    },
);

foreach my $kingdom (@kingdoms) {
    $kingdom->highest_town_count(8);
    $kingdom->highest_town_count_day_id($kingdom->inception_day_id);
    $kingdom->update;
}