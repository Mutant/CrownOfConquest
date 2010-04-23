#!/usr/bin/perl

use strict;
use warnings;

use lib '../lib','lib';

no warnings 'redefine';

use Test::Class::Load './lib/';

Test::Class->runtests(@ARGV);