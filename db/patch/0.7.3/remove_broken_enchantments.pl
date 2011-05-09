#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

my $config = RPG::LoadConf->load();
my $schema = RPG::Schema->connect( @{$config->{'Model::DBIC'}{connect_info}} );

my @broken = $schema->resultset('Item_Variable')->search(
    {
        name => ['Bonus', 'Extra Turns', 'Casts Per Day', 'Movement Bonus', 'Featherweight', 'Magical Damage Level', 'Spell Level', 'Daily Heal'],
        item_variable_value => {'<=', 0},
    }
);

foreach my $broken (@broken) {
    my $item = $schema->resultset('Items')->find(
        {
            item_id => $broken->item_id,
        }
    );
    
    if ($item->character_id) {
        $broken->item_variable_value($broken->name eq 'Featherweight' ? 10 : 1);
        $broken->update;
    }
    else {
        $item->delete;
    }
}