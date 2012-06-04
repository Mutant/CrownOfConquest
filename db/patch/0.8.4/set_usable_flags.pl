#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

use RPG::Schema::Dungeon;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @characters = $schema->resultset('Character')->search();

foreach my $character (@characters) {
    my @columns = qw(has_usable_actions_non_combat has_usable_actions_combat);
    
    for my $combat (0,1) {
        my @actions = $character->get_item_actions($combat);
        my $col = $columns[$combat];
        $character->$col(@actions ? 1 : 0);
    }
    $character->update;
}