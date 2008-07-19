#!/usr/bin/perl

use strict;
use warnings;

use RPG::Ticker;

$ENV{DBIC_TRACE} = 1;

RPG::Ticker->run();