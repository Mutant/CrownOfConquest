#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( @{$config->{'Model::DBIC'}{connect_info}} );

my @chars = $schema->resultset('Character')->search(
	{
		'mayor_of' => undef,
		'hit_points' => {'>', 0},
		'me.creature_group_id' => { '!=', undef },
		'creature_group.land_id' => undef,
	},
	{
		join => 'creature_group',
	},
);

map { $_->update( { creature_group_id => undef } ) } @chars;

warn scalar @chars . " chars updated\n";
