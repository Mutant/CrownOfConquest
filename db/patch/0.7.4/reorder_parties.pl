#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( @{$config->{'Model::DBIC'}{connect_info}} );

my @parties = $schema->resultset('Party')->search();

foreach my $party (@parties) {
    my $count = 1;
    foreach my $char ($party->characters_in_party) {
        if ($char->party_order != $count) {
            warn "Party " . $party->id . " order is messed up, fixing";
            $party->adjust_order;
            last;   
        }   
        $count++;
    }
}