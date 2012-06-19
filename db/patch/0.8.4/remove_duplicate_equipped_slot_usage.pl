#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

use RPG::Schema::Dungeon;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @dupes = $schema->resultset('Items')->search(
    {
        'character_id' => {'!=', undef},
        'equip_place_id' => {'!=', undef},
    },
    {
        '+select' => { 'count' => '*', -as => 'count' },
        'group_by' => [qw/character_id equip_place_id/],
        'having' => {'count' => {'>', 1}},
    }
);

foreach my $dupe (@dupes) {
    warn "Found dupe equip items for char " . $dupe->character_id . ", slot: " . $dupe->equip_place_id . "\n";
    
    my @items = $schema->resultset('Items')->search(
        {
            'character_id' => $dupe->character_id,
            'equip_place_id' => $dupe->equip_place_id,
        },
    );
    shift @items;            
    
    foreach my $item (@items) {
        $item->equip_place_id(undef);
        $item->update;
    }    
}