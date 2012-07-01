#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use Data::Dumper;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my $char_id = shift;

my @chars = $schema->resultset('Character')->search;

foreach my $char (@chars) {
    next if defined $char_id && $char_id != $char->id;
    warn "Processing char: " . $char->id;
    
    $schema->resultset('Item_Grid')->search(
        {
            owner_id => $char->id,
            owner_type => 'character',
        }
    )->delete;
    
    for my $x (1..8) {
        for my $y (1..8) {
            my $sector = $schema->resultset('Item_Grid')->find_or_create(
                {
                    owner_id => $char->id,
                    owner_type => 'character',
                    x => $x,
                    y => $y,
                }
            );
            $sector->item_id(undef);
            $sector->start_sector(undef);
            $sector->update;
        }
    }
    
    $char->organise_items;
}
    