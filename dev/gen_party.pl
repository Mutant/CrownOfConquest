#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use Digest::SHA1 qw(sha1_hex);

#  Find and read the correct local config file.
my $home = $ENV{RPG_HOME};
my $suffix = $ENV{CATALYST_CONFIG_LOCAL_SUFFIX};
my $localConfigFile = "$home/rpg_" . $suffix . ".yml";

#  Read the default config file.  Then, check for a local config file.  If it exists, also read it
#   and combine the config values.
my $config = RPG::LoadConf->load();

#  Use the local config values to connect to the game database.
my $schema;
if (defined $config->{'Model::DBIC'}) {
	$schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}}, );
} else {
	$schema = RPG::Schema->connect( "dbi:mysql:game", "root", "", { AutoCommit => 1 }, );
}
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