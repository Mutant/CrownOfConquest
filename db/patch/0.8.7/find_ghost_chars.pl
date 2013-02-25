#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
my $config = RPG::LoadConf->load();

use Try::Tiny;

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @towns = $schema->resultset('Town')->search();

foreach my $town (@towns) {
    my $mayor = $town->mayor;
    
    #next if ! $mayor || $mayor->is_npc;
    
    my @garrison_chars = $schema->resultset('Character')->search(
        {
            status => 'mayor_garrison',
            status_context => $town->id,
        }
    );
    
    foreach my $char (@garrison_chars) {
        if (! $mayor || $char->party_id != $mayor->party_id) {
            warn "Ghost char " . $char->id . " found in " . $town->id;
            warn "from party.. " . $char->party->id;
            $char->status(undef);
            $char->status_context(undef);
            $char->creature_group_id(undef);
            $char->update;
        }
               
    }
}