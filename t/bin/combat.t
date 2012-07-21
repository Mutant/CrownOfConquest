#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);

use lib "$Bin/../../lib","$Bin/../lib";

no warnings 'redefine';

use Test::Class::Load "$Bin/../lib/Test/RPG/Combat";

Test::Class->runtests(@ARGV);