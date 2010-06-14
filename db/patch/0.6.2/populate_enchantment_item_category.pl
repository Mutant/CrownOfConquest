#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use DateTime;

my $schema = RPG::Schema->connect( "dbi:mysql:game", "root", "", { AutoCommit => 1 }, );

my %DATA = (
	spell_casts_per_day => ['Melee Weapon', 'Armour', 'Head Gear', 'Ranged Weapon', 'Shield'],
	indestructible => ['Melee Weapon', 'Armour', 'Ranged Weapon'],
	magical_damage => ['Melee Weapon', 'Ranged Weapon'],
);

foreach my $enchantment_type (keys %DATA) {
	my $enchantment_rec = $schema->resultset('Enchantments')->find(
		{
			enchantment_name => $enchantment_type,
		}
	);
	
	foreach my $category (@{$DATA{$enchantment_type}}) {
		my $category_rec = $schema->resultset('Item_Category')->find(
			{
				item_category => $category,
			}
		);
		
		$schema->resultset('Enchantment_Item_Category')->find_or_create(
			{
				enchantment_id => $enchantment_rec->id,
				item_category_id => $category_rec->id,
			}
		);
	}	
}