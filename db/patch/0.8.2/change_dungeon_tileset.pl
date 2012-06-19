#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use Games::Dice::Advanced;
use List::Util qw(shuffle);

use RPG::Schema::Dungeon;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @dungeons = $schema->resultset('Dungeon')->search(
    {
        type => 'dungeon',
    },
    {
        prefetch => 'rooms',
    },
);

foreach my $dungeon (@dungeons) {
    foreach my $room ($dungeon->rooms) {
        my $tileset = (shuffle RPG::Schema::Dungeon::tilesets())[0];
        $room->tileset($tileset);
        $room->update;   
    }   
}
        