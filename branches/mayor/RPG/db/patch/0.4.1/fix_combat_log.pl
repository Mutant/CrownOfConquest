#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;

my $schema = RPG::Schema->connect( "dbi:mysql:game", "root", "", { AutoCommit => 1 }, );

my @combat_logs = $schema->resultset('Combat_Log')->search();

foreach my $log (@combat_logs) {
    next unless $log->land_id;
    
    my $land = $schema->resultset('Land')->find({land_id => $log->land_id});
    
    if (! $land) {
        my $dungeon_grid = $schema->resultset('Dungeon_Grid')->find({dungeon_grid_id => $log->land_id});
        
        if ($dungeon_grid) {
            $log->dungeon_grid_id($log->land_id);
            $log->land_id(undef);
            $log->update;   
        }
    }   
}
