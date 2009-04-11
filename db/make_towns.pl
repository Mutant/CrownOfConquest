#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;

use DBI;
use Games::Dice::Advanced;
use RPG::Map;
use RPG::Maths;
use Math::Round qw(round);
use List::Util qw(shuffle);

my $dbh = DBI->connect("dbi:mysql:game-copy","root","");
$dbh->{RaiseError} = 1;

my $towns = 30;

# Min distance a town can be from another one
my $town_dist_x = 13;
my $town_dist_y = 13;

my $min_x = 1;
my $min_y = 1;
my $max_x = 100;
my $max_y = 100;

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

#$dbh->do('delete from Town');
#$dbh->do('delete from Shop');
#$dbh->do('delete from Items where shop_id is not null');
#$dbh->do('delete from Items_Made');
#$dbh->do('delete from `Character` where town_id is not null');
#$dbh->do('delete from Quest');
#$dbh->do('delete from Quest_Param');

print "\nCreating $towns towns\n";

for (1 .. $towns) {
	my ($town_x, $town_y, $town_name);
	
	my $close_town;
	do {
		undef $close_town;
		
		my $x_range = $max_x - $min_x - 1;
		my $y_range = $max_y - $min_y - 1;
		
		$town_x = Games::Dice::Advanced->roll("1d$x_range") + $min_x - 1;
		$town_y = Games::Dice::Advanced->roll("1d$y_range") + $min_y - 1;

		warn "trying to creating town #$_ at: $town_x, $town_y\n"; 
		
		$town_name = generate_name();	    
	        		
		my @surrounds = RPG::Map->surrounds($town_x, $town_y, $town_dist_x, $town_dist_y);		
		
		#warn 'select * from Land join Terrain using (terrain_id) where terrain_name = "town" and x >= ' . $surrounds[0]->{x}
		#	. ' and x <= ' . $surrounds[1]->{x} . ' and y >= ' . $surrounds[0]->{y} . ' and y <= ' . $surrounds[1]->{y};
		
		my @close_town = $dbh->selectrow_array('select * from Town join Land using (land_id) where x >= ' . $surrounds[0]->{x}
			. ' and x <= ' . $surrounds[1]->{x} . ' and y >= ' . $surrounds[0]->{y} . ' and y <= ' . $surrounds[1]->{y});
		
		#warn Dumper \@close_town;
		
		$close_town = 1 if @close_town;
		
	    print "Can't create town at $town_x,$town_y .. too close to another town.\n" if $close_town;

		#warn Dumper $close_town;
	} while (defined $close_town);
	
	my ($land_id) = $dbh->selectrow_array("select land_id from Land where x=$town_x and y=$town_y"); 

    die "No land id found for $town_x, $town_y ($land_id)" unless $land_id;
	
	$dbh->do("update Land set terrain_id = $town_terrain_id, creature_threat = 0 where land_id = $land_id"); 
	
	$dbh->do("delete from Dungeon where land_id = $land_id");
	$dbh->do("delete from Creature_Group where land_id = $land_id");
	$dbh->do("delete from Creature_Orb where land_id = $land_id");	
	
	my $prosp = RPG::Maths->weighted_random_number(1..100);
	
	$dbh->do(
		'insert into Town(town_name, land_id, prosperity) values (?,?,?)',
		{},
		$town_name, $land_id, $prosp,
	);
	
    warn "Sucessfully created town #$_ at: $town_x, $town_y\n";
}

sub generate_name {
	open(my $names_fh, '<', 'town_names.txt') || die "Couldn't open names file ($!)\n";
	my @names = <$names_fh>;
	close ($names_fh);
	
	chomp @names;
	my @shuffled = shuffle @names;
	
	my $name_to_use;
	
	foreach my $name (@shuffled) {
	   my @dupe_town = $dbh->selectrow_array("select * from Town where town_name = '$name'");
	   
	   unless (@dupe_town) {
	       $name_to_use = $name;
	       last;
	   }	
	}
	
	die "No available names" unless $name_to_use;
	
	return $name_to_use;
}

sub generate_prosperity {
	my $prosp;
	
	my @row =$dbh->selectrow_array("select count(*) from Town");
	my $num_of_towns = shift @row;
	
	while (! $prosp) {
		$prosp = Games::Dice::Advanced->roll("1d100");
		
		return $prosp unless $num_of_towns;
		
		my $prosp_idx = $prosp-1;	
		my $prosp_range = $prosp_idx - $prosp_idx % 10;	
		
		my $max_percent = $prosp_limits{$prosp_range};
		
 		my @row = $dbh->selectrow_array("select count(*) from Town where prosperity > $prosp_range+1 and prosperity <= $prosp_range+10");
		my $current_count = shift @row;
	
		my $current_percent = ($current_count / $num_of_towns * 100);
	
		warn "Prosp: $prosp; range: $prosp_range; max: $max_percent; current: $current_count; current_percent: $current_percent\n";
		
		if ($current_percent >= $max_percent) {
			warn "too many towns in this prosp range... ($current_count)\n";
			undef $prosp;	
		}		
	}
	
	return $prosp;
}