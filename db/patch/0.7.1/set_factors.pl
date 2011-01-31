#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( @{$config->{'Model::DBIC'}{connect_info}} );

my @chars = $schema->resultset('Character')->search();

foreach my $char (@chars) {
	$char->calculate_attack_factor;
	$char->calculate_defence_factor;	

	$char->update;
}