#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
my $config = RPG::LoadConf->load();

use Try::Tiny;

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my $item_rs = $schema->resultset('Items')->search(
    {
        equip_place_id => undef,
        'me.character_id' => {'!=', undef},
    },
    {
        join => 'belongs_to_character',
    },
);

while (my $item = $item_rs->next) {
    next if $item->grid_sectors->count >= 1;
    
    warn $item->id . " is not equipped, and belongs to char, but is not in grid"; 
    
    my $char = $item->belongs_to_character;
    
    eval {
        $char->add_item_to_grid($item);
    };
    if ($@) {
        warn "Failed adding item to grid: $@";
    };
}