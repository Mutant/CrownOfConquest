#!/usr/bin/perl

use strict;
use warnings;

use lib '/home/sam/RPG/lib';

use RPG::NewDay;

my $new_day = RPG::NewDay->new();
$new_day->run();