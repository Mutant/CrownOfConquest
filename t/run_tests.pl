#!/usr/bin/perl

use strict;
use warnings;

use lib '../lib','lib';

use Test::Class::Load './lib/Test/RPG/Schema','./lib/Test/RPG/C', './lib/Test/RPG/NewDay';

Test::Class->runtests(@ARGV);
