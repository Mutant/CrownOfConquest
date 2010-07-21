#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;

my $schema = RPG::Schema->connect( "dbi:mysql:game", "root", "", { AutoCommit => 1 }, );

my @dungeons = $schema->resultset('Dungeon')->search(
	{},
	{
		prefetch => 'location',
	}
);

foreach my $dungeon (@dungeons) {
	$schema->resultset('Mapped_Sectors')->search(
		{
			land_id => $dungeon->location->land_id,
		},
	)->update(
		{
			known_dungeon => $dungeon->level,
		}
	);
}