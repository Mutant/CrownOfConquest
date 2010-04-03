#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::Map;

$|=1;

my $schema = RPG::Schema->connect( "dbi:mysql:game2", "root", "root", );

my @dungeons = $schema->resultset('Dungeon')->search;

foreach my $dungeon (@dungeons) {
	print "Processing dungeon_id: " . $dungeon->id . "\n";
	
	my @sectors = $schema->resultset('Dungeon_Grid')->search(
		{
			'dungeon_room.dungeon_id' => $dungeon->id,
		},
		{
			join => 'dungeon_room',
		},
	);
	
	print "... " . scalar @sectors . " sectors\n";
	
	my $count = 0;
	
	foreach my $sector (@sectors) {
		$count++;
		if ($count % 30 == 0) {
			print ".";	
		}
		
		my ( $top_corner, $bottom_corner ) = RPG::Map->surrounds_by_range( $sector->x, $sector->y, 3 );
		
		my @surrounds;
		{
			no warnings;
		    @surrounds = $schema->resultset('Dungeon_Grid')->search(
		        {
		            x                         => { '>=', $top_corner->{x}, '<=', $bottom_corner->{x} },
		            y                         => { '>=', $top_corner->{y}, '<=', $bottom_corner->{y} },
		            'dungeon_room.dungeon_id' => $dungeon->id,
		        },
		        {
		            prefetch => [ 
		            	'dungeon_room', 
		            	{ 'doors' => 'position' },
		            	{ 'walls' => 'position' },
		            ],
		
		        },
		    );
		    
		}
		    
	    my $surrounds_by_coord;
	    foreach my $surround (@surrounds) {
	    	$surrounds_by_coord->[$surround->x][$surround->y] = $surround;	
	    }
	    
	    my $allowed_to_move_to = $sector->allowed_to_move_to_sectors( \@surrounds, 3 );
	    
	    for my $y ($top_corner->{y} .. $bottom_corner->{y}) {
			for my $x ($top_corner->{x} .. $bottom_corner->{x}) {
				next unless $allowed_to_move_to->[$x][$y];
				
				my $distance = RPG::Map->get_distance_between_points(
					{
						x=> $sector->x,
						y=> $sector->y,
					},
					{
						x=>$x,
						y=>$y,	
					}
				);
				
				$schema->resultset('Dungeon_Sector_Path')->create(
					{
						sector_id => $sector->id,
						has_path_to => $surrounds_by_coord->[$x][$y]->id,
						distance => $distance,
					}
				);								
			}
	    }	
	}
	
	print "\n...Done.\n";
	
}