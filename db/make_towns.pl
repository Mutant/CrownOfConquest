#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;

use DBI;
use Games::Dice::Advanced;
use RPG::Map;
use Math::Round qw(round);
use List::Util qw(shuffle);

my $dbh = DBI->connect("dbi:mysql:scrawley_game:mutant.dj","scrawley_user","***REMOVED***");
$dbh->{RaiseError} = 1;

my $towns = 40;

# Min distance a town can be from another one
my $town_dist_x = 12;
my $town_dist_y = 12;

my $max_x = 40;
my $max_y = 40;

my %prosp_limits = (
	90 => 2,
	80 => 3,
	70 => 5,
	60 => 5,
	50 => 12,
	40 => 13,
	30 => 15,
	20 => 15,
	10 => 15,
	0  => 15,		
);

my ($town_terrain_id) = $dbh->selectrow_array('select terrain_id from Terrain where terrain_name = "town"');

$dbh->do("update Land set terrain_id = 1 where terrain_id = $town_terrain_id");

$dbh->do('delete from Town');

print "\nCreating $towns towns\n";

for (1 .. $towns) {
	my ($town_x, $town_y, $town_name);
	
	my $close_town;
	do {
		undef $close_town;
		
		$town_x = Games::Dice::Advanced->roll("1d$max_x");
		$town_y = Games::Dice::Advanced->roll("1d$max_y");

		warn "creating town #$_ at: $town_x, $town_y\n"; 
		
		$town_name = generate_name();
	    
	    my @dupe_town = $dbh->selectrow_array("select * from Town where town_name = '$town_name'");
	    
	    $close_town = 1, next if @dupe_town;
		
		my @surrounds = RPG::Map->surrounds($town_x, $town_y, $town_dist_x, $town_dist_y);		
		
		#warn 'select * from Land join Terrain using (terrain_id) where terrain_name = "town" and x >= ' . $surrounds[0]->{x}
		#	. ' and x <= ' . $surrounds[1]->{x} . ' and y >= ' . $surrounds[0]->{y} . ' and y <= ' . $surrounds[1]->{y};
		
		my @close_town = $dbh->selectrow_array('select * from Land join Terrain using (terrain_id) where terrain_name = "town" and x >= ' . $surrounds[0]->{x}
			. ' and x <= ' . $surrounds[1]->{x} . ' and y >= ' . $surrounds[0]->{y} . ' and y <= ' . $surrounds[1]->{y});
		
		#warn Dumper \@close_town;
		
		$close_town = 1 if @close_town;
		
	    print "Can't create town at $town_x,$town_y .. too close to another town.\n" if $close_town;

		#warn Dumper $close_town;
	} while (defined $close_town);
	
	my ($land_id) = $dbh->selectrow_array("select land_id from Land where x=$town_x and y=$town_y"); 
	
	$dbh->do("update Land set terrain_id = $town_terrain_id, creature_threat = 0 where land_id = $land_id"); 
	
	$dbh->do(
		'insert into Town(town_name, land_id, prosperity) values (?,?,?)',
		{},
		$town_name, $land_id, generate_prosperity(),
	);
}

sub generate_name {
	open(my $names_fh, '<', 'town_names.txt') || die "Couldn't open names file ($!)\n";
	my @names = <$names_fh>;
	close ($names_fh);
	
	chomp @names;
	my @shuffled = shuffle @names;
	
	return $shuffled[0];
}

sub generate_prosperity {
	my $prosp;
	while (! $prosp) {
		$prosp = Games::Dice::Advanced->roll("1d100");
		
		my $prosp_idx = $prosp-1;	
		my $prosp_range = $prosp_idx - $prosp_idx % 10;	
		
		my $max_percent = $prosp_limits{$prosp_range};
		
 		my @row = $dbh->selectrow_array("select count(*) from Town where prosperity > $prosp_range+1 and prosperity <= $prosp_range+10");
		my $current_count = shift @row;
	
		my $current_percent = ($current_count / $towns * 100);
	
		warn "Prosp: $prosp; range: $prosp_range; max: $max_percent; current: $current_count; current_percent: $current_percent\n";
		
		if ($current_percent >= $max_percent) {
			warn "too many towns in this prosp range... ($current_count)\n";
			undef $prosp;	
		}		
	}
	
	return $prosp;
}