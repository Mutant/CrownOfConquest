package RPG::Schema::Role::Item_Grid;

use Moose::Role;
use Carp;

requires qw/item_sectors search_related id result_source/;

sub organise_items_in_tabs {
    my $self = shift;
    my $owner_type = shift;
    my $width = shift;
    my $height = shift;
    my @items = @_;
        
    $self->item_sectors->delete;
      
    my $max_tab;
    for my $tab (1..10) {
        $self->create_grid($owner_type, $width, $height, $tab);
        
        @items = $self->organise_items_impl($tab, @items);
                
        $max_tab = $tab;
        
        last unless @items;
    }
    
    warn scalar @items . " items remaining when organising into tabs" if @items;
}

sub create_grid {
    my $self = shift;
    my $owner_type = shift;
    my $width = shift;
    my $height = shift;
    my $tab = shift // 1;
    
    my @data;
    
    for my $x (1..$width) {
        for my $y (1..$height) {
            push @data, [ $self->id, $owner_type, $x, $y, $tab ];
        }
    }
    
    $self->result_source->schema->populate('Item_Grid', [
            [ qw/ owner_id owner_type x y tab /],
            @data,
        ]
    );   
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
    
    #warn "tab: $tab";
        
    $self->search_related('item_sectors', { tab => $tab })->update(
        {
            start_sector => undef,
            item_id => undef,
        }
    );
    
    my @sectors = $self->search_related('item_sectors', { tab => $tab });
    my %sectors;
    
    foreach my $sector (@sectors) {
        $sectors{$sector->x . "," . $sector->y} = $sector;   
    }
        
    my @remaining_items;
            
    while (my $item = shift @items) {
        #warn "item: " . $item->id;
        
        my @coords = sort by_coord keys %sectors;
        
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
                        
            my @sector_ids;
            
            foreach my $sector (@sectors_to_use) {
                push @sector_ids, $sector->id;
                delete $sectors{$sector->x.",".$sector->y};
            }
            
            $self->result_source->schema->resultset('Item_Grid')->search(
                {
                    item_grid_id => \@sector_ids,
                },
            )->update( { item_id => $item->id } );                    
            
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
        
        croak "Couldn't find room for item" unless $start_coord;
        
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
                order_by => 'y,x',
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