#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use Games::Dice::Advanced;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @characters = $schema->resultset('Character')->search();

my @resistances = qw/fire ice poison/;

foreach my $char (@characters) {
    foreach my $resistance (@resistances) {
        my $method = "resist_${resistance}";
        $char->$method(Games::Dice::Advanced->roll($char->level . 'd3'));
    }
    $char->update;
}