#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::Map;
use RPG::NewDay::Context;
use RPG::NewDay::Action::Dungeon;

use YAML;
use Log::Dispatch;
use DateTime;

$|=1;

my $dungeon_id = $ARGV[0];

my $schema = RPG::Schema->connect( "dbi:mysql:game", "root", "", );

my @dungeons = $dungeon_id ? $schema->resultset('Dungeon')->find($dungeon_id) : $schema->resultset('Dungeon')->search;

    my $home = $ENV{RPG_HOME};

    my $config = YAML::LoadFile("$home/rpg.yml");
    if ( -f "$home/rpg_local.yml" ) {
        my $local_config = YAML::LoadFile("$home/rpg_local.yml");
        $config = { %$config, %$local_config };
    }
    
    my $logger = Log::Dispatch->new
          ( outputs =>
            [ [ 'Screen',
                min_level => 'debug',
                stderr    => 1,
                newline   => 1 ]
            ],
          );

    my $context = RPG::NewDay::Context->new(
        config      => $config,
        schema      => $schema,
        logger      => $logger,
        datetime    => DateTime->now(),
    );
    
my $populator = RPG::NewDay::Action::Dungeon->new( context => $context );

unless ($dungeon_id) {
	$schema->resultset('Dungeon_Sector_Path')->delete;
	$schema->resultset('Dungeon_Sector_Path_Door')->delete;
}

foreach my $dungeon (@dungeons) {
	print "Processing dungeon_id: " . $dungeon->id . "...\n";

	$populator->populate_sector_paths($dungeon);
	
	print "\n...Done.\n";
	
}