#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use Data::Dumper;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my $shop_id = shift;

my @shops = $schema->resultset('Shop')->search;

foreach my $shop (@shops) {
    next if defined $shop_id && $shop_id != $shop->id;
    warn "Processing shop: " . $shop->id;
    
    for my $x (1..8) {
        for my $y (1..12) {
            my $sector = $schema->resultset('Item_Grid')->find_or_create(
                {
                    owner_id => $shop->id,
                    owner_type => 'shop',
                    x => $x,
                    y => $y,
                }
            );
            $sector->item_id(undef);
            $sector->start_sector(undef);
            $sector->update;
        }
    }

    my @items = $shop->search_related(
        'items_in_shop',
        {},
        {
            join => {'item_type' => 'category'},
            order_by => 'category.item_category',
        }
    );
    
    foreach my $item (@items) {
        #warn "Checking for item: " . $item->id;
        my @empty_sectors = $schema->resultset('Item_Grid')->search(
            {
                item_id => undef,
            },
        );
        my %empty_sectors;
        foreach my $sector (@empty_sectors) {
            $empty_sectors{$sector->x . ',' . $sector->y} = $sector;
        }
                
        COORD: foreach my $coord (sort by_coord keys %empty_sectors) {
            my ($start_x,$start_y) = split /,/, $coord;
            
            my $end_x = $start_x + $item->item_type->height - 1;
            my $end_y = $start_y + $item->item_type->width  - 1;
            
            #warn "$start_x, $end_x, $start_y, $end_y";
            
            my @sectors_to_use;
            for my $x ($start_x..$end_x) {
                for my $y ($start_y..$end_y) {
                     if (! $empty_sectors{"$x,$y"}) {                         
                         next COORD;
                     }
                     push @sectors_to_use, $empty_sectors{"$x,$y"};
                }
            }
            
            foreach my $sector (@sectors_to_use) {
                $sector->item_id($item->id);
                $sector->update;
            }
                        
            my $sector = $empty_sectors{$coord};
            $sector->start_sector(1);
            $sector->update;
            
            last;
        }
        
        # TODO: do something if no space found
    }
       
}

sub by_coord($$) {
    my ($a, $b) = @_;
    
    my ($x1, $y1) = split /,/, $a;
    my ($x2, $y2) = split /,/, $b;
    
    return $y1 <=> $y2 if $x1 == $x2;
    return $x1 <=> $x2;       
}