#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use YAML;
use Digest::SHA1 qw(sha1_hex);

my $schema = RPG::Schema->connect( "dbi:mysql:game", "root", "", { AutoCommit => 1 }, );
my $home = $ENV{RPG_HOME};

my $config = YAML::LoadFile("$home/rpg.yml");
RPG::Schema->config($config);

my $player_name = shift || die "Please provide a player name\n";
my $level = shift || die "Please provide a level";
my $char_count = shift // 6;

my $player = $schema->resultset('Player')->create(
	{
		player_name => $player_name,
		email => $player_name . '@email.com',
		password => sha1_hex('pass'),		
		verified => 1,
	},
);

my $land = $schema->resultset('Land')->find(
	{},
	{
		rows => 1,
	}
);
		

my $party = $schema->resultset('Party')->create(
	{
		name => "$player_name\'s Party",
		land_id => $land->id,	
		player_id => $player->id,
		gold => 100000,
		turns => 1000,
		created => DateTime->now(),
	}
);

for (1..$char_count) {
	my $character = $schema->resultset('Character')->generate_character(
		allocate_equipment => 1,
		level              => $level,
	);
	$character->party_id($party->id);
	$character->update;
} 