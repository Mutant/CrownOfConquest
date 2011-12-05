#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @characters = $schema->resultset('Character')->search();

foreach my $character (@characters) {
    next if $character->level <= 1;
    
    my $allocated_skill_points = $character->search_related(
        'character_skills',        
    )->get_column('level')->sum_rs;
    
    if ($character->level - 1 < $allocated_skill_points + $character->skill_points) {
        warn "Char " . $character->id . " skill points out of whack (" . $character->level . ", $allocated_skill_points, " . $character->skill_points . ")";
        $character->skill_points($character->level - 1 - $allocated_skill_points);
        $character->update;
    }
    
}
            