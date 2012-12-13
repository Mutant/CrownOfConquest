#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @players = $schema->resultset('Player')->search(
    {
        deleted => 1,
    }
);

foreach my $player (@players) {
    my $last_party = $schema->resultset('Party')->find(
        {
            player_id => $player->id,
        },
        {
            order_by => 'defunct desc',
            rows => 1,
        },
    );
    
    next if ! $last_party;
    
    $player->deleted_date($last_party->defunct);
    $player->update;
}