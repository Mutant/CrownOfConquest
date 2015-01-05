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

    my %equip_places_used;
	
	my @items = $char->items;
	
	foreach my $item (@items) {
		next unless $item->equip_place_id;
		
		if ($equip_places_used{$item->equip_place_id}) {
		    warn "Item already equipped in " .  $item->equip_place_id . " for char " . $char->id;
		    $item->equip_place_id(undef);
		    $item->update;
		    next;
		}
		
		$equip_places_used{$item->equip_place_id} = 1;
		
		$item->_stat_bonus_trigger($item->equip_place_id, $char);
	}
	
	$char->update;
		
}