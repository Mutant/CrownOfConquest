#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( @{$config->{'Model::DBIC'}{connect_info}} );

my @chars = $schema->resultset('Character')->search();

foreach my $char (@chars) {
	$char->strength_bonus(0);
	$char->intelligence_bonus(0);
	$char->agility_bonus(0);
	$char->constitution_bonus(0);
	$char->divinity_bonus(0);
	
	my @items = $char->items;
	
	foreach my $item (@items) {
		next unless $item->equip_place_id;
		
		$item->_stat_bonus_trigger($item->equip_place_id, $char);
	}
	
	$char->update;
		
}