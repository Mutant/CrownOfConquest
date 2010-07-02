#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;

my $schema = RPG::Schema->connect( "dbi:mysql:game", "root", "", { AutoCommit => 1 }, );

my @items = $schema->resultset('Items')->search(
	{
		treasure_chest_id => {'!=', undef},
		'item_type.item_type' => 'Artifact',		
	},
	{
		join => 'item_type',
	},
);

foreach my $item (@items) {
	my $quest_param = $schema->resultset('Quest_Param')->find(
		{
			start_value => $item->id,
			quest_param_id => 11,
		}
	);
	
	$item->delete unless $quest_param;
}