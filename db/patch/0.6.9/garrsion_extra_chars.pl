#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( @{$config->{'Model::DBIC'}{connect_info}} );

my @parties = $schema->resultset('Party')->search();

foreach my $party (@parties) {
	if ($party->characters_in_party->count > $config->{max_party_characters}) {
		warn $party->name . " has " . $party->characters_in_party->count . " characters";
	}			
}