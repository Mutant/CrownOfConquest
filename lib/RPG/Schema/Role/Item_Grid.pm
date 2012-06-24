package RPG::Schema::Role::Item_Grid;

use Moose::Role;

requires qw/item_sectors search_related/;

sub organise_items {
    my $self = shift;
    
    $self->item_sectors->update(
        {
            start_sector => undef,
            item_id => undef,
        }
    );      
    
    my @sectors = $self->item_sectors;
    my %sectors;
    
    foreach my $sector (@sectors) {
        $sectors{$sector->x . "," . $sector->y} = $sector;   
    }
    
    my @items = $self->search_related('items',
        {},
        {
            prefetch => {'item_type' => 'category'},
            order_by => 'category.item_category',            
        }
    );            
    
    foreach my $item (@items) {
        next if $item->equipped;
        
        COORD: foreach my $coord (sort by_coord keys %sectors) {
            my ($start_x,$start_y) = split /,/, $coord;
            
            my $end_x = $start_x + $item->item_type->height - 1;
            my $end_y = $start_y + $item->item_type->width  - 1;
            
            #warn "$start_x, $end_x, $start_y, $end_y";
            my $start_sector = $sectors{$coord};
            
            my @sectors_to_use;
            for my $y ($start_y..$end_y) {
                for my $x ($start_x..$end_x) {                
                     if (! $sectors{"$x,$y"}) {                         
                         next COORD;
                     }
                     push @sectors_to_use, $sectors{"$x,$y"};                     
                }
            }
            
            foreach my $sector (@sectors_to_use) {
                $sector->item_id($item->id);
                $sector->update;
                delete $sectors{$sector->x.",".$sector->y};
            }
            
            $start_sector->start_sector(1);
            $start_sector->update;
            
            last;
        }    
        
        # TODO: add to next tab
    }        
       
}

sub items_in_grid {
    my $self = shift;
    
    my @sectors = $self->search_related('item_sectors',
        {
            start_sector => 1,
            'me.item_id' => {'!=', undef},
        },
        {
            prefetch => {'item' => {'item_type' => 'category'}},
        },
    );
    
    my $grid;
    
    foreach my $sector (@sectors) {
        $grid->{$sector->x}{$sector->y} = $sector->item;
    }
    
    return $grid;
       
}

sub remove_item_from_grid {
    my $self = shift;
    my $item = shift;
    
	$self->search_related('item_sectors',
	   {
	       item_id => $item->id,
	   }
    )->update( { item_id => undef } );       
}

sub add_item_to_grid {
    my $self = shift;
    my $item = shift;
    my $start_coord = shift;
    
    $self->search_related('item_sectors',
        {
            x => { '>=', $start_coord->{x}, '<=', $start_coord->{x} + $item->item_type->width - 1, },
            y => { '>=', $start_coord->{y}, '<=', $start_coord->{y} + $item->item_type->height - 1, },
        }
    )->update( { item_id => $item->id } );
    
    $self->search_related('item_sectors',
        {
            x => $start_coord->{x},
            y => $start_coord->{y},
        },
    )->update( { start_sector => 1 } );
}

sub by_coord($$) {
    my ($a, $b) = @_;
    
    my ($x1, $y1) = split /,/, $a;
    my ($x2, $y2) = split /,/, $b;
    
    return $x1 <=> $x2 if $y1 == $y2;
    return $y1 <=> $y2;
}

1;