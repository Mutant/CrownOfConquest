#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

my %CREATURE_SPELLS = (
    'Orc Shaman' => [qw/Summon Shield Bless Heal Weaken/],
    'Warlock' => ['Summon','Blades','Confuse','Slow','Energy Beam'],
    'Black Sorcerer' => [qw/Summon Haste Bless Shield Entangle/],
    'Lich' => [qw/Summon Flame Bless Confuse Slow/],
);

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( @{$config->{'Model::DBIC'}{connect_info}} );

foreach my $type (keys %CREATURE_SPELLS) {
    my $ct = $schema->resultset('CreatureType')->find(
        {
            creature_type => $type,
        }
    );
    die "$type not found" unless $ct;
    
    foreach my $spell (@{ $CREATURE_SPELLS{$type} }) {
        my $spell_rec = $schema->resultset('Spell')->find(
            {
                spell_name => $spell,
            }
        );
        $ct->add_to_spells({spell_id=>$spell_rec->id});   
    }   
}