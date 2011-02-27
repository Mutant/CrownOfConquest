#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use RPG::Schema::Kingdom;

use File::Slurp;
use List::Util qw(shuffle);
use Games::Dice::Advanced;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( @{$config->{'Model::DBIC'}{connect_info}} );

my @kingdoms = shuffle read_file($config->{data_file_path} . '/kingdoms.txt');

my @colours = shuffle (RPG::Schema::Kingdom->colours);

for (1..12) {
    my $kingdom_name = shift @kingdoms;
    chomp $kingdom_name;
    
    my $colour = shift @colours;    
    
    my $kingdom = $schema->resultset('Kingdom')->create(
        {
            name => $kingdom_name,
            colour => $colour,
        }
    );
    
    # Find a starting sector for this kingdom
    my $start_sector = $schema->resultset('Land')->find(
        {
            kingdom_id => undef,
        },
        {
            order_by => \'rand()',
            rows => 1,
        }
    );
    
    $start_sector->kingdom_id($kingdom->id);
    $start_sector->update;    
    
    my ($start_point, $end_point) = RPG::Map->surrounds_by_range( $start_sector->x, $start_sector->y, 21 );
    
    $schema->resultset('Land')->search(
        {
            kingdom_id => undef,
            'x' => { '>=', $start_point->{x}, '<=', $end_point->{x}, },
            'y' => { '>=', $start_point->{y}, '<=', $end_point->{y}, },            
        },
    )->update(
        {
            kingdom_id => $kingdom->id
        }
    );
}