#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use RPG::Schema;

$ENV{DBIC_TRACE} = 1;

my $creature_count = shift @ARGV || 10;

my $schema = RPG::Schema->connect(
	"dbi:mysql:game",
    "root",
     "",
	{AutoCommit => 1},
);	

my $max_x = 20;
my $max_y = 20;

$schema->resultset('Creature')->delete;
$schema->resultset('CreatureGroup')->delete;

my @creature_types = $schema->resultset('CreatureType')->search();

for my $count (1 .. $creature_count) {
	my %cords;	
	my $land;
	while (! %cords) {
		%cords = (
			x => int (rand $max_x) + 1,
			y => int (rand $max_y) + 1,
		);
		
		warn Dumper \%cords;

		($land) = $schema->resultset('Land')->search(
			x => $cords{x},
			y => $cords{y}				
		);
	
		my $already_cg = $schema->resultset('CreatureGroup')->search(
			land_id => $land->id,
		)->count;
		
		undef %cords unless $already_cg == 0;	
	}

	my $cg = $schema->resultset('CreatureGroup')->create({
		land_id => $land->id,
	});
	
	my $number = int (rand 7) + 3;
	my $index = int rand $#creature_types;
	my $type = $creature_types[$index];
		
	for my $creature (1 .. $number) {
		
		my $hps = int (rand 10) * $type->level + 1;
		
		$schema->resultset('Creature')->create({
			creature_type_id => $type->id,
			creature_group_id => $cg->id,
			hit_points_current => $hps,
			hit_points_max => $hps,
		});
	}
}
