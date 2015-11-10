#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( @{$config->{'Model::DBIC'}{connect_info}} );

my @parties = $schema->resultset('Party')->search(
    {
        defunct => undef,    
    },
);

foreach my $party (@parties) {
    next if $party->player && $party->player->player_id;
    
    $party->deactivate;
    $party->update;   
}
