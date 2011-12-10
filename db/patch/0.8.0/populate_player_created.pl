#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use DateTime;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( @{$config->{'Model::DBIC'}{connect_info}} );

my @players = $schema->resultset('Player')->search();

foreach my $player (@players) {
    my @parties = $player->parties;
        
    my $first_party;
    if (scalar @parties == 1) {
        $first_party = $parties[0];
    }
    else {
        @parties = grep { $_->created } @parties;
        @parties = sort { $a->created cmp $b->created } @parties;
        $first_party = $parties[0];
    }
    
    if ($first_party && $first_party->created) {
        $player->created($first_party->created);
    }
    else {
        warn "No created date found for " . $player->id;
        $player->created(DateTime->now()->subtract(months=>1));
    } 

    $player->update;
}