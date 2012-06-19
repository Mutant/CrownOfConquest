#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

use Games::Dice::Advanced;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my %item_types_by_prevalence = $schema->resultset('Item_Type')->get_by_prevalence;

my @chests = $schema->resultset('Treasure_Chest')->search(
   {
       'dungeon.type' => {'!=', 'castle'},
       'dungeon_room.special_room_id' => undef, # Treasure rooms shouldn't be re-filled
   },
   {
       join => {'dungeon_grid' => {'dungeon_room' => 'dungeon'}},
   },
);
	
foreach my $chest (@chests) {
    $chest->items->delete;
	if (Games::Dice::Advanced->roll('1d100') <= $config->{empty_chest_fill_chance}) {
		$chest->fill(%item_types_by_prevalence);
	} 	

}