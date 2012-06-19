#!/usr/bin/perl

use strict;
use warnings;

#use lib '../lib','lib';
my $home = $ENV{RPG_HOME} . "/lib";
eval "use lib '$home';";

use Test::Harness;

if ($ARGV[0] && $ARGV[0] eq '--refresh-schema') {
	shift @ARGV;
	
	print "# Refreshing schema...\n";
	
	my $dumpFile; my $rmProg;
	if ( $^O =~ /MSWin32/ ) {
		$dumpFile = $ENV{RPG_HOME} . "\\db_dump";
		$rmProg = 'del';
	} else {
		$dumpFile = '/tmp/db_dump';
		$rmProg = 'rm';
	}
	system("mysqldump -u root -d game > $dumpFile");
	system("mysqldump -u root -t game Equip_Places Class Race Spell Quest_Type Quest_Param_Name Levels Dungeon_Position Enchantments Dungeon_Special_Room Building_Type Skill Map_Tileset Building_Upgrade_Type >> $dumpFile");
	system("mysql -u root game_test < $dumpFile");
	system("$rmProg $dumpFile");
}

runtests('run_test_classes.pl');
