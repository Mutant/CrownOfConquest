#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use DateTime;

my $schema = RPG::Schema->connect( "dbi:mysql:game", "root", "", { AutoCommit => 1 }, );

my @party = $schema->resultset('Party')->search(
	{},
);

foreach my $party (@party) {
	unless ($party->player) {
		$party->defunct(DateTime->now());
		$party->update;	
	}
}