#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

use List::Util qw(shuffle);

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

my $file = $config->{data_file_path} . 'quest_items.txt';
open( my $names_fh, '<', $file ) || die "Couldn't open names file: $file ($!)\n";
my @item_names = <$names_fh>;
close($names_fh);
chomp @item_names;

    my $item_type = $schema->resultset('Item_Type')->find(
    	{
    		item_type => 'Artifact',
    	}
   	);

foreach my $quest (@quests) {
    next if $quest->param_current_value('Item Found');
    
    my $item = $quest->item;
    
    next if $item;
    
    my $dungeon = $quest->dungeon;

    my @chests = $schema->resultset('Treasure_Chest')->search(
    	{
    		'dungeon.dungeon_id' => $dungeon->id,
    	},
    	{
    		join => { 'dungeon_grid' => { 'dungeon_room' => 'dungeon' }},
    	}    	
    );
    
    my $item_name = (shuffle @item_names)[0];
    
    my $chest = (shuffle @chests)[0];
    
    $item = $schema->resultset('Items')->create(
    	{
    		item_type_id => $item_type->id,
    		name => $item_name,
    		treasure_chest_id => $chest->id,
    	}
    );
    
    my $param_record = $quest->param_record('Item');
    $param_record->start_value($item->id);
    $param_record->current_value($item->id);
    $param_record->update;
    
}