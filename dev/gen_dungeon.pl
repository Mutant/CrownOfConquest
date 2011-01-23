#!/usr/bin/perl

use strict;
use warnings;

use RPG::LoadConf;
use RPG::Schema;
use RPG::NewDay::Context;
use RPG::NewDay::Action::Creatures;
use DateTime;

package GenDungeon;

use Moose;

extends 'RPG::NewDay::Base';

with 'RPG::NewDay::Role::DungeonGenerator';

1;

package DebugLogger;

use Moose;

sub debug {
	print $_[1] . "\n";
}

sub info {
	print $_[1] . "\n";
}

1;

package main;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}}, );

my ($level, $floors, $x, $y, $rooms, $spawn_monsters) = @ARGV;
die "Please provide the following params: level, floors, x, y (latter two are coords for dungeon)\n" 
	unless $level && $floors && $x && $y;
	
$rooms //= 20;
	
my $land = $schema->resultset('Land')->find({ x=> $x, y => $y });
die "Can't find land at $x, $y" unless $land;

die "Already a dungeon there" if $land->dungeon;

my $dungeon = $schema->resultset('Dungeon')->create(
	{
    	land_id => $land->id,
        level   => $level,
        type => 'dungeon',
	}
);

my @rooms;
for (1..$floors) {
	push @rooms, $rooms;
}

my $context = RPG::NewDay::Context->new(
	config => $config,
	schema => $schema,
	logger => DebugLogger->new(),
	datetime => DateTime->now(),
);

my $generator = GenDungeon->new(
	context => $context,
);

$generator->generate_dungeon_grid($dungeon, \@rooms);
$generator->populate_sector_paths($dungeon);

if ($spawn_monsters) {
	RPG::NewDay::Action::Creatures->_spawn_in_dungeon($context, $dungeon);	
}