#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use Log::Dispatch;
use Log::Dispatch::File;
use YAML;
use DateTime;
use RPG::NewDay::Action::Dungeon;
use RPG::NewDay::Context;

my $schema = RPG::Schema->connect( "dbi:mysql:game", "root", "", { AutoCommit => 1 }, );

my $home = $ENV{RPG_HOME};
die "RPG_HOME not defined\n" unless $home;
my $config = YAML::LoadFile("$home/rpg.yml");
if ( -f "$home/rpg_local.yml" ) {
    my $local_config = YAML::LoadFile("$home/rpg_local.yml");
    $config = { %$config, %$local_config };
}

my $logger = Log::Dispatch->new( callbacks => sub { return '[' . localtime() . "] [$$] " . $_[1] . "\n" } );
    $logger->add(
        Log::Dispatch::File->new(
            name      => 'file1',
            min_level => 'debug',
            filename  => $config->{log_file_dir} . 'new_day.log',
            mode      => 'append',
            stamp_fmt => '%Y%m%d',
        ),
    );
    
    my $context = RPG::NewDay::Context->new(
        config      => $config,
        schema      => $schema,
        logger      => $logger,
        datetime    => DateTime->now(),
    );
    
my @dungeons = $schema->resultset('Dungeon')->search;

my $dungeon_action = RPG::NewDay::Action::Dungeon->new({context => $context});

foreach my $dungeon (@dungeons) {
	$dungeon_action->generate_treasure_chests($dungeon);	
}