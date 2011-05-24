#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @quests = $schema->resultset('Quest')->search(
    {
        'type.quest_type' => 'destroy_orb',
        status => ['Not Started', 'In Progress'],
    },
    {
        prefetch => 'type',
    }
);

foreach my $quest (@quests) {
    if (! $quest->orb_to_destroy->land_id) {
        if ($quest->status eq 'Not Started') {
            $quest->delete;
        }
        else {
            my $land = $quest->town->location;
            my $new_land = $schema->resultset('Land')->find(
                {
                    x => $land->x + 5,
                    y => $land->y + 7,
                }
            );
            
            if ($new_land) {
                my $orb = $quest->orb_to_destroy;
                $orb->land_id($new_land->id);
                $orb->update;
            }
            else {
                $quest->delete;
            }
        }
    }  
}