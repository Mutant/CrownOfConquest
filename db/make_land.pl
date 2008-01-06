#!/usr/bin/perl

use strict;
use warnings;

use DBI;

my $dbh = DBI->connect("dbi:mysql:game","root","");
$dbh->{RaiseError} = 1;

my $max_x = 20;
my $max_y = 20;

my ($max_terrain) = $dbh->selectrow_array('select max(terrain_id) from Terrain');

$dbh->do('delete from Land');

for my $x (1 .. $max_x) {
    for my $y (1 .. $max_y) {
        my $terrain_id = (int rand $max_terrain) +1;
        $dbh->do(
            'insert into Land(x, y, terrain_id) values (?,?,?)',
            {},
            $x, $y, $terrain_id,
        );
    }
}
