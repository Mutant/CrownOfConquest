#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;

my $schema = RPG::Schema->connect( "dbi:mysql:game", "root", "", { AutoCommit => 1 }, );

my $rs = $schema->resultset('Mapped_Sectors')->search(
	{
		known_dungeon => {'!=', 0},
	},
	{
		join => {'location' => 'town'},
	},
);

while (my $row = $rs->next) {
	if ($row->location->town) {
		$row->known_dungeon(0);
		$row->update;
	}	
}