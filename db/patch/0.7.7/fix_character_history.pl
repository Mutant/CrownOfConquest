#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @bad_history = $schema->resultset('Character_History')->search(
    {
        event => { like => '%slain by 2%'},
    }
);

foreach my $history (@bad_history) {
    my $event = $history->event;
    $event =~ s/slain by 2/slain by a/;
    $history->event($event);
    $history->update;   
}