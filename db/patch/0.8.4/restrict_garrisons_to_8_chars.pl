#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use List::Util qw(shuffle);
use Try::Tiny;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @garrisons = $schema->resultset('Garrison')->search(
    {
        land_id => {'!=', undef},
    },
);

foreach my $garrison (@garrisons) {
    my $char_count = $garrison->characters->count; 
    
    next if $char_count <= 8;
    
    my @chars = $garrison->characters;
    
    foreach my $char (@chars) {
        if ($char->is_dead) {
            $char->status_context($garrison->land_id);
            $char->status('corpse');
            $char->garrison_id(undef);
            $char->update;
            warn "Making dead char in " . $garrison->id . " a corpse" . "\n";
            $char_count--;
            last if $char_count <= 8; 
        }
    }
    
    next if $char_count <= 8;
    
    my $location = $garrison->land;
    
    my @towns = try {
        $schema->resultset('Town')->find_in_range(
            {
                x => $location->x,
                y => $location->y,
            },
            5,
            2,
            0,
            15,
        );
    }
    catch {
        if (ref $_ && $_->type eq 'find_in_range_error') {
            next;
        }
        die $_;
    };    
    
    my $town = (shuffle @towns)[0];
    
    foreach my $char (@chars) {
        next if $char->is_dead;
        $char->status_context($town->id);
        $char->status_context('inn');
        $char->garrison_id(undef);
        $char->update;
        $char_count--;
        warn "Moving char in " . $garrison->id . " to town " . $town->id . "\n";
        last if $char_count <= 8;   
    }
}
        