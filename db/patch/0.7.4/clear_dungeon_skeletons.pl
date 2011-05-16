#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @dungeons = $schema->resultset('Dungeon')->search();

foreach my $dungeon (@dungeons) {
    my $skel_count = $schema->resultset('Dungeon_Grid')->search(
        {
            'dungeon_room.dungeon_id' => $dungeon->id,
            'overlay' => 'skeleton',
        },
        {
            join => 'dungeon_room',
        }
    )->count;
    
    my $grid_rs = $schema->resultset('Dungeon_Grid')->search(
        {
            'dungeon_room.dungeon_id' => $dungeon->id,
        },
        {
            join => 'dungeon_room',
        }        
    );
    
    if ($skel_count >= $grid_rs->count) {
        $grid_rs->update( { overlay => undef } );   
    }
}