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

my @rooms = $schema->resultset('Dungeon_Room')->search(
    {
        'dungeon.type' => 'dungeon',
        'me.tileset' => undef,
    },
    {
        join => 'dungeon',
    },
);

foreach my $room (@rooms) {
    my $tileset = (shuffle RPG::Schema::Dungeon::tilesets())[0];
    $room->tileset($tileset);
    $room->update;   
}
        