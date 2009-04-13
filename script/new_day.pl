#!/usr/bin/perl

use strict;
use warnings;

use lib '/home/sam/RPG/lib';

use RPG::NewDay;

my $new_day = RPG::NewDay->new();
my $error = $new_day->run(@ARGV);
print $error if $error;