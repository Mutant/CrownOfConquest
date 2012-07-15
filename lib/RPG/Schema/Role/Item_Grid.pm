package RPG::Schema::Role::Item_Grid;

use Moose::Role;

requires qw/item_sectors search_related id result_source/;

sub organise_items_in_tabs {
    my $self = shift;
    my $owner_type = shift;
    my $width = shift;
    my $height = shift;
    my @items = @_;
   
    my $max_tab;
    for my $tab (1..10) {
        for my $x (1..$width) {
            for my $y (1..$height) {
                my $sector = $self->result_source->schema->resultset('Item_Grid')->find_or_create(
                    {
                        owner_id => $self->id,
                        owner_type => $owner_type,
                        x => $x,
                        y => $y,
                        tab => $tab,
                    }
                );
            }
        }
        
        @items = $self->organise_items_impl($tab, @items);
        
        $max_tab = $tab;
        
        last unless @items;
    }
    
    $self->search_related('item_sectors',
        {
            tab => {'>', $max_tab},
        }
    )->delete;
    
    warn scalar @items . " items remaining when organising into tabs" if @items;
}

sub organise_items {
    my $self = shift;
 
    my @items = $self->search_related('items',
        {
            'equip_place_id' => undef,
        },
        {
            prefetch => {'item_type' => 'category'},
            order_by => 'category.item_category, me.item_id',            
        }
    );
    
    my @remaining = $self->organise_items_impl(1, @items);
    
    warn scalar @remaining . " items remaining when organising into tabs" if @remaining; 
}

sub organise_items_impl {
    my $self = shift;
    my $tab = shift;
    my @items = @_;
    
    $self->item_sectors->update(
        {
            start_sector => undef,
            item_id => undef,
            tab => $tab,
        }
    );    
    
    my @sectors = $self->search_related('item_sectors', { tab => $tab });
    my %sectors;
    
    foreach my $sector (@sectors) {
        $sectors{$sector->x . "," . $sector->y} = $sector;   
    }
    
    my @coords = sort by_coord keys %sectors;
    
    my @remaining_items;
        
    while (my $item = shift @items) {
        #warn "item: " . $item->id;
        
        my $placed = 0;
        
        COORD: foreach my $coord (@coords) {
            my ($start_x,$start_y) = split /,/, $coord;
            
            my $end_x = $start_x + $item->item_type->width  - 1;
            my $end_y = $start_y + $item->item_type->height - 1;
            
            #warn "$start_x, $start_y; $end_x, $end_y";
            my $start_sector = $sectors{$coord};
            
            my @sectors_to_use;
            for my $x ($start_x..$end_x) {
                for my $y ($start_y..$end_y) {
                     if (! $sectors{"$x,$y"}) {                         
                         next COORD;
                     }
                     push @sectors_to_use, $sectors{"$x,$y"};                     
                }
            }
            
            #warn scalar @sectors_to_use . ' < ' . ($item->item_type->width * $item->item_type->height);
            
            next if scalar @sectors_to_use < ($item->item_type->width * $item->item_type->height);
            
            foreach my $sector (@sectors_to_use) {
                $sector->item_id($item->id);
                $sector->update;
                delete $sectors{$sector->x.",".$sector->y};
            }
            
            $start_sector->start_sector(1);
            $start_sector->update;
            
            $placed = 1;
            
            last;
        }
        
        push @remaining_items, $item if ! $placed;
    }
    
    return @remaining_items;
}

sub by_coord($$) {
    my ($a, $b) = @_;
    
    my ($x1, $y1) = split /,/, $a;
    my ($x2, $y2) = split /,/, $b;
    
    return $x1 <=> $x2 if $y1 == $y2;
    return $y1 <=> $y2;
}

sub items_in_grid {
    my $self = shift;
    my $tab = shift // 1;
    
    my @sectors = $self->search_related('item_sectors',
        {
            start_sector => 1,
            'me.item_id' => {'!=', undef},
            'tab' => $tab,
        },
        {
            prefetch => {'item' => { 'item_type' => 'category' } },
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
    )->update( { item_id => undef, start_sector => undef, } );       
}

sub add_item_to_grid {
    my $self = shift;
    my $item = shift;
    my $start_coord = shift;
    my $tab = shift // 1;
    
    confess "Can't add equipped item to grid" if $item->equipped;
    
    if (! $start_coord) {
        $start_coord = $self->find_location_for_item($item);
        $tab = $start_coord->{tab};
    }
    
    confess "No start coords" if ! $start_coord || ! $start_coord->{x} || ! $start_coord->{y};
    
    #warn "startX: " . $start_coord->{x} . "; endX: " . ($start_coord->{x} + $item->item_type->width  - 1);
    #warn "startY: " . $start_coord->{y} . "; endY: " . ($start_coord->{y} + $item->item_type->height - 1);
    
    my @sectors = $self->search_related('item_sectors',
        {
            x => { '>=', $start_coord->{x}, '<=', $start_coord->{x} + $item->item_type->width  - 1, },
            y => { '>=', $start_coord->{y}, '<=', $start_coord->{y} + $item->item_type->height - 1, },
            tab => $tab,
        }
    );
        
    $sectors[0]->start_sector(1);
    
    foreach my $sector (@sectors) {
        if ($sector->item_id) {
            confess "Can't add item to grid sectors " . $sector->x . "," . $sector->y . " when item " . $sector->item_id . " already there";
        }
        $sector->item_id($item->id);
        $sector->update;
    }
     
}

sub find_location_for_item {
    my $self = shift;
    my $item = shift;
    
    my $max_tab = $self->max_tab;
    
    for my $tab (1..$max_tab) {    
        my @sectors = $self->search_related('item_sectors',
            {
                item_id => undef,
                tab => $tab,
            },
            {
                order_by => 'x,y',
            },
        );
        
        my $grid;
        foreach my $sector (@sectors) {
            $grid->{$sector->x}{$sector->y} = $sector;
        }
        
        foreach my $sector (@sectors) {
            my $sectors_found = 0;
            
            #warn "startX " . $sector->x . "; endX" . $sector->x + $item->item_type->width - 1;
            #warn "startY " . $sector->y . "; endY" . $sector->y + $item->item_type->height - 1;
            
            for my $x ($sector->x .. $sector->x + $item->item_type->width - 1) {
                for my $y ($sector->y .. $sector->y + $item->item_type->height - 1) {
                    $sectors_found++ if $grid->{$x}{$y};   
                }
            }
            
            if ($sectors_found >= ($item->item_type->width * $item->item_type->height)) {
                return {
                    x => $sector->x,
                    y => $sector->y,
                    tab => $tab,
                }   
            }
        }
    }
}

sub max_tab {
    my $self = shift;
    
    my $max_tab = $self->find_related('item_sectors',
        {},
        {
            'select' => { max => 'tab' },
            'as'     => 'max_tab',
        }
    )->get_column('max_tab');
    
    return $max_tab;
               
}

1;