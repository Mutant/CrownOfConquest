#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use Games::Dice::Advanced;
use Math::Round qw(round);

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @towns = $schema->resultset('Town')->search();

foreach my $town (@towns) {
    my @hires = $schema->resultset('Town_Guards')->search(
		{
			town_id => $town->id,
		}
	);
	
	foreach my $hire (@hires) {
        my $percent_lost = Games::Dice::Advanced->roll('1d4') * 10;
        my $new_amount = round ($hire->amount * (100 - $percent_lost) / 100);
        $hire->amount($new_amount);
        $hire->amount_working($new_amount);
        $hire->update;
	}
}