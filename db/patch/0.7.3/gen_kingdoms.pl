#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use RPG::Schema::Kingdom;

use File::Slurp;
use List::Util qw(shuffle);
use Games::Dice::Advanced;
use Data::Dumper;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( @{$config->{'Model::DBIC'}{connect_info}} );

my @kingdoms = shuffle read_file($config->{data_file_path} . '/kingdoms.txt');

my @colours = shuffle (RPG::Schema::Kingdom->colours);

my $redo_count = 0;

for (1..12) {
    last if $redo_count == 10;
    
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
    my $town = $schema->resultset('Town')->find(
        {
            'location.kingdom_id' => undef,
        },
        {
            order_by => \'rand()',
            rows => 1,
            join => 'location',
        }
    );
    my $start_sector = $town->location;
    
    warn "start sector: " . $start_sector->x . ',' . $start_sector->y;
    
    $start_sector->kingdom_id($kingdom->id);
    $start_sector->update;
    
    my $size = 500 + (Games::Dice::Advanced->roll('1d700'));
    warn "Creating kingdom of size: $size";
    
    my %joinable;
    my $in_kingdom;
    $in_kingdom->[$start_sector->x][$start_sector->y] = 1;
    
    push @{$joinable{$start_sector->x . ',' . $start_sector->y}}, (1,2,3,4,6,7,8,9);
        
    # Make sectors around town part of kingdom
   
    my $failures = 0;

    while ($size > 0 && $failures < 5000) {        
        my $key;
        if (! %joinable) {
            # No sectors left to join, find another one at random
            my $sector = $schema->resultset('Land')->find(
                {
                    kingdom_id => undef,
                },
                {
                    order_by => \'rand()',
                    rows => 1,
                }                
            );
            
            last unless $sector; 
            
            $key = $start_sector->x . ',' . $start_sector->y;
            
            push @{$joinable{$key}}, (1,2,3,4,6,7,8,9);
        }
        else {        
            $key = (shuffle keys %joinable)[0];
        }
        
        my ($x, $y) = split /,/, $key;
        my $coord = {x=>$x, y=>$y};
        
        my @dirs = shuffle @{$joinable{$key}};        
        my $direction = shift @dirs;
        #warn "Orig: $key\n";
        #warn "Direction: $direction\n";
        
        if (@dirs) {
            $joinable{$key} = \@dirs;
        }
        else {
            #warn "No more sides left for $key";
            delete $joinable{$key};
        }
        
        my $new_coord = RPG::Map->adjust_coord_by_direction($coord, $direction);        
       
        my $sector;
        
        $sector = $schema->resultset('Land')->find(
            {
                x=>$new_coord->{x},
                y=>$new_coord->{y},
                kingdom_id => undef,
            }
        ) unless $in_kingdom->[$new_coord->{x}][$new_coord->{y}];
        
        if (! $sector) {
            #warn "Can't find sector: " . Dumper $new_coord;
            $failures++;
            next;   
        }
        
        $sector->kingdom_id($kingdom->id);
        $sector->update;
        
        $size--;
        
        $in_kingdom->[$new_coord->{x}][$new_coord->{y}] = 1;
        
        my ($start_point, $end_point) = RPG::Map->surrounds_by_range($new_coord->{x}, $new_coord->{y}, 1);
        
        my $new_key = $new_coord->{x} . ',' . $new_coord->{y};
        
        foreach my $check_x ($start_point->{x} .. $end_point->{x}) {
            foreach my $check_y ($start_point->{y} .. $end_point->{y}) {
                if (! $in_kingdom->[$check_x][$check_y]) {
                    my $direction = RPG::Map->find_direction_to_adjacent_sector(
                        $new_coord,
                        {
                            x => $check_x,
                            y => $check_y,
                        }
                    );
                    
                    push @{$joinable{$new_key}}, $direction;  
                }
            }
        }
        
        #warn "New coord $new_key has these sides: " . Dumper $joinable{$new_key};
    }
    
    warn "Size remaining: $size, failures: $failures\n";
    
    my $kingdom_size = $schema->resultset('Land')->search(
        {
            kingdom_id => $kingdom->id,
        },
    )->count;
    
    my $town_count = $schema->resultset('Land')->search(
        {
            kingdom_id => $kingdom->id,
            'town.town_id' => {'!=', undef},
        },
        {
            join => 'town',
        }
    )->count;
    
    warn "Land size: $kingdom_size, town count: $town_count";
    
    if ($kingdom_size <= 500 || $town_count < 6) {
        $schema->resultset('Land')->search(
            {
                kingdom_id => $kingdom->id,
            },
        )->update(
            {
                kingdom_id => undef,
            }
        );
        $kingdom->delete;
        push @colours, $colour;
        $redo_count++;
        
        warn "removing... (count: $redo_count)\n";
        redo;          
    }
}
