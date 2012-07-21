#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);

use lib "$Bin/../../lib","$Bin/../lib";

no warnings 'redefine';

use Test::RPG::Ticker::LandGrid;
use Test::RPG::BlastWeighted;
use Test::RPG::Map;
use Test::RPG::Maths;
use Test::RPG::NewDay;

Test::Class->runtests(@ARGV);