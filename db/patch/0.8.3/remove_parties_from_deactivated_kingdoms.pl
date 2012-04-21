#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @parties = $schema->resultset('Party')->search(
    {
        'kingdom.active' => 0,
    },
    {
        join => 'kingdom',
    }
);

foreach my $party (@parties) {
    $party->change_allegiance(undef);
    $party->update;   
}