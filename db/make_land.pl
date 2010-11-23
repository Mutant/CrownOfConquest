#!/usr/bin/perl

use strict;
use warnings;

$| = 1;

use Data::Dumper;

use DBI;
use Games::Dice::Advanced;
use RPG::Map;

my $dbh = DBI->connect("dbi:mysql:scrawley_game:mutant.dj","scrawley_user","***REMOVED***");
#my $dbh = DBI->connect("dbi:mysql:game_test","root","root");
$dbh->{RaiseError} = 1;

my $min_x = 1;
my $min_y = 1;
my $max_x = 100;
my $max_y = 100;

my ($max_terrain) = $dbh->selectrow_array('select max(terrain_id) from Terrain');
my ($town_terrain_id) = $dbh->selectrow_array('select terrain_id from Terrain where terrain_name = "town"');

#$dbh->do('delete from Land');

my $map;
my %terrain_count;

print "Creating a $max_x x $max_y world";

my $previous_ctr;

for my $x ($min_x .. $max_x) {
    for my $y ($min_y .. $max_y) {
        my ($land_id) = $dbh->selectrow_array("select land_id from Land where x=$x and y=$y");
        
        next if $land_id;
        
        my $terrain_id = get_terrain_id($x, $y);        
        
        $map->[$x][$y] = $terrain_id;
        $terrain_count{$terrain_id}++;
        
        my $creature_threat;
        if (defined $previous_ctr) {
        	my $rand = (int rand 20) - 10;
        	
        	$creature_threat = $previous_ctr + $rand;
        	$creature_threat = 0 if $creature_threat < 0;
        	$creature_threat = 100 if $creature_threat > 100;
        }
        else {
        	$creature_threat = 50;	
        }
        
        $previous_ctr = $creature_threat;
        
        $dbh->do(
            'insert into Land(x, y, terrain_id, creature_threat) values (?,?,?,?)',
            {},
            $x, $y, $terrain_id, $creature_threat,
        );
    }
    print ".";
}
#exit;
print "Done!\n";

sub get_terrain_id {
	my ($x, $y) = @_;
	
	my @adjacent;
	
	# Find adjacent squares
	foreach my $test_x ($x-1 .. $x+1) {
		foreach my $test_y ($y-1 .. $y+1) {
			push @adjacent, $map->[$test_x][$test_y] if defined $map->[$test_x][$test_y];
		}
	}
	
	# Find probabilities of each terrain type
	my %probs;
	my $total_prob;
	foreach my $adj (@adjacent) {
		my $percent = int (100 - ($terrain_count{$adj} / ($max_x*$max_y) * 100)) / 4;
		
		$probs{$adj}+=$percent;
		$total_prob+=$percent;
	}
	
	# Roll dice, and see if one of ours matches
	my $terrain_id;
	my $roll = Games::Dice::Advanced->roll("1d100");
	foreach my $terrain_type (keys %probs) {
		if ($probs{$terrain_type} <= $roll) {
			$terrain_id = $terrain_type;
			last;
		}
		else {
			$roll-= $probs{$terrain_type};
		}		
	}
	
	# Didn't find a terrain, so generate a random one. 
	unless ($terrain_id) {
		do {
	    	$terrain_id = (int rand $max_terrain) +1;
	    } while ($terrain_id == $town_terrain_id);
	}
	
	return $terrain_id;
	
}