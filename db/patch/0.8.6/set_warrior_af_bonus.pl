#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my @characters = $schema->resultset('Character')->search(
    {
        'class.class_name' => 'Warrior',
    },
    {
        join => 'class',
    }
);

foreach my $char (@characters) {
    $char->calculate_attack_factor;
    $char->update;
}