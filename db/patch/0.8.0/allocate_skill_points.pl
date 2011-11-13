#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use Games::Dice::Advanced;
use List::Util qw(shuffle);

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( @{$config->{'Model::DBIC'}{connect_info}} );

my @skills = $schema->resultset('Skill')->search();
my @characters = $schema->resultset('Character')->search();

foreach my $character (@characters) {
    next if $character->level <= 1;
    
    my $skill_points = $character->level - 1;
    
    if (! $character->is_npc) {
        $character->skill_points($skill_points);
        $character->update;   
    }
    else {
        @skills = shuffle @skills;
                
        foreach my $skill (@skills) {
            if ($skill->skill_name eq 'Recall' && ! $character->is_spell_caster) {
                next;
            }            
            
            my $level = Games::Dice::Advanced->roll('1d10');
            
            $level = $skill_points if $level > $skill_points;
            
            $character->add_to_character_skills(
                {
                    skill_id => $skill->id,
                    level => $level,
                }
            );
            
            $skill_points -= $level;
            
            last if $skill_points <= 0;
        }
    }
}