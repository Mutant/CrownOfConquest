#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;

my $schema = RPG::Schema->connect( "dbi:mysql:game", "root", "", );

my $rs = $schema->resultset('Items')->search(
	{
		'category.item_category' => 'Ammunition',
	},
	{
		join => { 'item_type' => 'category' },
	}
);

while (my $ammo = $rs->next) {
	$ammo->delete if $ammo->variable('Quantity') <= 0;	
}
		