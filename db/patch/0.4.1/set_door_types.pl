#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use Games::Dice::Advanced;
use List::Util qw/shuffle/;

$| = 1;

my $schema = RPG::Schema->connect( "dbi:mysql:game", "root", "", { AutoCommit => 1 }, );

my @doors = $schema->resultset('Door')->search();

my $processed_doors;

my @alternative_door_types = qw/stuck locked sealed secret/;

my $count = 0;
foreach my $door (@doors) {
    $count++;
    unless ( $processed_doors->[ $door->id ] ) {
        my $opp_door = $door->opposite_door;

        if ( Games::Dice::Advanced->roll('1d100') <= 15 ) {
            my $door_type = ( shuffle(@alternative_door_types) )[0];
            $door->type($door_type);
            $door->update;


            if ($opp_door) {
                $opp_door->type($door_type);
                $opp_door->update;
            }
            
            warn "No opp door found for door id: " . $door->id . "\n" unless $opp_door;
        }

        $processed_doors->[ $door->id ] = 1;
        $processed_doors->[ $opp_door->id ] = 1 if $opp_door;
    }

    if ( $count % 100 == 0 ) {
        print ".";
    }
}
