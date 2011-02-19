#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

use List::Util qw(shuffle);
use Games::Dice::Advanced;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( @{$config->{'Model::DBIC'}{connect_info}} );

my @dungeons = $schema->resultset('Dungeon')->search();
foreach my $dungeon (@dungeons) {
    my $tileset = (shuffle qw/rocky burrow/)[0];
    $tileset = 'castle' if $dungeon->type eq 'castle';
    $dungeon->update({tileset => $tileset});
}

my $grid_rs = $schema->resultset('Dungeon_Grid')->search();
while (my $sector = $grid_rs->next) {
    $sector->tile(1);
    # See if we should use a 'rare' tile
    if (Games::Dice::Advanced->roll('1d100') <= 15) {
        $sector->tile(Games::Dice::Advanced->roll('1d3')+1);
    }
    
    # See if there's an overlay
    $sector->overlay(undef);
    if ($sector->stairs_up || $sector->stairs_down || $sector->teleporter || $sector->treasure_chest) {
    }
    elsif (Games::Dice::Advanced->roll('1d100') <= 3) {
        $sector->overlay('skeleton');   
    }
    
    $sector->update;
} 