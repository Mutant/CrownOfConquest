#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @quests = $schema->resultset('Quest')->search(
    {
        status => {'!=', ['Complete', 'Terminated', 'Cancelled']},
        'kingdom.active' => 0,
    },
    {
        join => 'kingdom',
    }
);

foreach my $quest (@quests) {
    $quest->status('Terminated');
    $quest->cleanup;
    $quest->update;
}