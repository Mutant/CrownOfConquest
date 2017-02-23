#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;

my $schema = RPG::Schema->connect(
	"dbi:mysql:game",
    "root",
    "root",
	{AutoCommit => 1},
);

my @characters = $schema->resultset('Character')->search;

foreach my $character (@characters) {
    my $name = $character->character_name;
    $name =~ s/\n//g;
    $character->character_name($name);
    $character->update;
}