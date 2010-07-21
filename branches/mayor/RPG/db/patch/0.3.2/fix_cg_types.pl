#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;

my $schema = RPG::Schema->connect( "dbi:mysql:game", "root", "", { AutoCommit => 1 }, );

my @cgs = $schema->resultset('CreatureGroup')->search(
    {
        -or => {
            land_id => {'!=', undef},
            dungeon_grid_id => {'!=', undef},
        },
    },
    {
        prefetch => 'creatures',
    }
);

foreach my $cg (@cgs) {
    my %orders_to_types;
    foreach my $creature ($cg->creatures) {
        if ($orders_to_types{$creature->group_order}{$creature->creature_type_id}) {
            print "Duplicates found in cg: " . $cg->id . ". Removing...\n";
            
            $cg->update(
                {
                    land_id => undef,
                    dungeon_grid_id => undef,
                }
            );
            
            last;   
        }
        
        $orders_to_types{$creature->group_order}{$creature->creature_type_id} = 1;
    }       
}