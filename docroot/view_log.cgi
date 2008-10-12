#!/usr/bin/perl

use strict;
use warnings;

open(FILE, '/home/scrawley/game/debug.log');
my @log = <FILE>;
close (FILE);

print "Content-type: text/html\n\n";
print qq|<body><p  style="font-family: courier; size: 10px">|;
foreach my $line (reverse @log) {
	print "$line<br>\n";	
} 
print "</p></body>";