#!/usr/bin/perl

use strict;
use warnings;

use lib '../lib','lib';

use Test::Class::Load './lib/';

if ($ARGV[0] eq '--refresh-schema') {
	shift @ARGV;
	
	`mysqldump -u root -d game > /tmp/db_dump`;
	`mysql -u root game-test < /tmp/db_dump; rm /tmp/db_dump`;
}

Test::Class->runtests(@ARGV);
