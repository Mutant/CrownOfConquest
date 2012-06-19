#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @quests = $schema->resultset('Quest')->search(
    {
        status => ['In Progress', 'Not Started'],
        'type.quest_type' => 'destroy_orb',
    },
    {
        join => 'type',
    }
);

foreach my $quest (@quests) {
    my $orb = $quest->orb_to_destroy;
    if (! $orb->land_id) {
        $quest->delete;   
    }   
}