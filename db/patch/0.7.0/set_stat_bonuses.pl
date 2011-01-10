#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( @{$config->{'Model::DBIC'}{connect_info}} );

my @chars = $schema->resultset('Character')->search();

my @items_with_stat_bonuses = $schema->resultset('Items')->search(
		{
			'enchantment.enchantment_name' => 'stat_bonus',
			'equip_place_id' => {'!=', undef},
		},
		{
			prefetch => {'item_enchantments' => 'enchantment'},
		}
);

foreach my $item (@items_with_stat_bonuses) {
	$item->_stat_bonus_trigger($item->equip_place_id);
}