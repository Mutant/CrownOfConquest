#!/usr/bin/perl

use strict;
use warnings;

use lib '../lib','lib';

use Test::Class::Load './lib/Test/RPG';

Test::Class->runtests(@ARGV);
