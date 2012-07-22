#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use Data::Dumper;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @garrisons = $schema->resultset('Garrison')->search( { land_id => {'!=', undef} });

foreach my $garrison (@garrisons) {
    warn "Organising " . $garrison->id;    
    $garrison->organise_equipment;       
}