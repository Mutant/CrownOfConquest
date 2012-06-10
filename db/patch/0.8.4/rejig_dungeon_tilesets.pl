#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use Games::Dice::Advanced;

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
        if (Games::Dice::Advanced->roll('1d100') < 20) {
            $room->tileset('wood');
            $room->update;   
        }
    }   
}
        