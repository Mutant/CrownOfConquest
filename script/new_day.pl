#!/usr/bin/perl

use strict;
use warnings;

my $home = $ENV{RPG_HOME} . "/lib";
eval "use lib '$home';";

use RPG::NewDay;

my $new_day = RPG::NewDay->new();
my $error = $new_day->run(@ARGV);
print $error if $error;