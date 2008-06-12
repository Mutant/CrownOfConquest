#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;

use DBI;
use Games::Dice::Advanced;
use RPG::Map;

my $dbh = DBI->connect("dbi:mysql:game","root","");
$dbh->{RaiseError} = 1;

my $towns = 200;

# Max distance a town can be from another one
my $town_dist_x = 7;
my $town_dist_y = 7;

my $max_x = 100;
my $max_y = 100;

my ($town_terrain_id) = $dbh->selectrow_array('select terrain_id from Terrain where terrain_name = "town"');

$dbh->do("update Land set terrain_id = 1 where terrain_id = $town_terrain_id");

$dbh->do('delete from Town');

print "\nCreating $towns towns\n";

for (1 .. $towns) {
	my ($town_x, $town_y);
	
	my $close_town;
	do {
		undef $close_town;
		
		$town_x = Games::Dice::Advanced->roll("1d$max_x");
		$town_y = Games::Dice::Advanced->roll("1d$max_y");

		warn "creating town #$_ at: $town_x, $town_y\n"; 
		
		my @surrounds = RPG::Map->surrounds($town_x, $town_y, $town_dist_x, $town_dist_y);		
		
		warn 'select * from Land join Terrain using (terrain_id) where terrain_name = "town" and x >= ' . $surrounds[0]->{x}
			. ' and x <= ' . $surrounds[1]->{x} . ' and y >= ' . $surrounds[0]->{y} . ' and y <= ' . $surrounds[1]->{y};
		
		my @close_town = $dbh->selectrow_array('select * from Land join Terrain using (terrain_id) where terrain_name = "town" and x >= ' . $surrounds[0]->{x}
			. ' and x <= ' . $surrounds[1]->{x} . ' and y >= ' . $surrounds[0]->{y} . ' and y <= ' . $surrounds[1]->{y});
		
		warn Dumper \@close_town;
		
		$close_town = 1 if @close_town;
		
	    print "Can't create town at $town_x,$town_y .. too close to another town.\n" if $close_town;

		#warn Dumper $close_town;
	} while (defined $close_town);
	
	my ($land_id) = $dbh->selectrow_array("select land_id from Land where x=$town_x and y=$town_y"); 
	
	$dbh->do("update Land set terrain_id = $town_terrain_id, creature_threat = 0 where land_id = $land_id"); 
	
	$dbh->do(
		'insert into Town(town_name, land_id, prosperity) values (?,?,?)',
		{},
		"Town #$_", $land_id, Games::Dice::Advanced->roll("1d100"),
	);
}