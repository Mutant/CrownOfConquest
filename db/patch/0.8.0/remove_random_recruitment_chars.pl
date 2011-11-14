#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use Games::Dice::Advanced;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( @{$config->{'Model::DBIC'}{connect_info}} );

my @chars = $schema->resultset('Character')->search(
    {
        town_id => {'!=', undef},
        party_id => undef,
    }
);

foreach my $char (@chars) {
    next if Games::Dice::Advanced->roll('1d100') < 50;

    $char->delete;   
}