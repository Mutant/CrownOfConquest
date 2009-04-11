#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use Games::Dice::Advanced;

my $schema = RPG::Schema->connect( "dbi:mysql:game:mutant.dj", "root", "***REMOVED***", { AutoCommit => 1 }, );

my @towns = $schema->resultset('Town')->search();

foreach my $town (@towns) {
    next if $town->blacksmith_age > 0;
    
    if (Games::Dice::Advanced->roll('1d3') != 1) {
        $town->blacksmith_age(Games::Dice::Advanced->roll('1d6'));
        $town->blacksmith_skill(Games::Dice::Advanced->roll('1d6'));
        $town->update;
    }   
}