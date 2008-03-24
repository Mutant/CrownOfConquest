#!/usr/bin/perl

use strict;
use warnings;

use RPG::NewDay;

$ENV{DBIC_TRACE} = 1;

RPG::NewDay->run();