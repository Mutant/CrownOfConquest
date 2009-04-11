#!/usr/bin/perl

use strict;
use warnings;

use File::Slurp qw(read_dir);
use RPG::Schema;

my $schema = RPG::Schema->connect( "dbi:mysql:game", "root", "", { AutoCommit => 1 }, );

my @files = read_dir( '/home/sam/RPG/docroot/static/images/items' ) ;

foreach my $image (@files) {
    $image =~ /^(\d+)/;
    my $type_id = $1;
    
    $schema->resultset('Item_Type')->find($type_id)->update({image => $image});
}