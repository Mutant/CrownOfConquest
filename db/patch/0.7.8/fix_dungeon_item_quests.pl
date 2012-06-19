#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @quests = $schema->resultset('Quest')->search(
	{
		'type.quest_type' => 'find_dungeon_item',
		status => ['Not Started', 'In Progress'],
	},
	{
		join => 'type',
	}
);

foreach my $quest (@quests) {
    my $item = $quest->item;
    my $chest = $schema->resultset('Treasure_Chest')->find($item->treasure_chest_id);
    if (! $chest) {
        warn $quest->id . " for item in non-existant chest";  
        $quest->delete; 
    }   
}