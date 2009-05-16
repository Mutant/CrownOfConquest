#!/usr/bin/perl

use strict;
use warnings;

use lib '../lib','lib';

use Test::Harness;

if ($ARGV[0] && $ARGV[0] eq '--refresh-schema') {
	shift @ARGV;
	
	print "# Refreshing schema...\n";
	
	system("mysqldump -u root -d game > /tmp/db_dump");	
	system("mysqldump -u root -t game Equip_Places Class Race Spell Quest_Type Quest_Param_Name >> /tmp/db_dump");
	system("mysql -u root game-test < /tmp/db_dump; rm /tmp/db_dump");
}

runtests('run_test_classes.pl');