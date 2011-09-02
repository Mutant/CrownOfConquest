package RPG::NewDay::Action::Town_Loyalty;

# Calculate the loyalty of towns for their kingdoms

use Moose;

extends 'RPG::NewDay::Base';

use RPG::Map;

use Data::Dumper;
use Carp;
use Math::Round qw(round);

sub depends { qw/RPG::NewDay::Action::Kingdom/ }

sub run {
    my $self = shift;
    my $c = $self->context;
    
    my $schema = $c->schema;
            
    my @kingdoms = $schema->resultset('Kingdom')->search(
        {
            active => 1,
        }
    );
    
    foreach my $kingdom (@kingdoms) {
        $c->logger->debug("Calculating town loyalty for kingdom: " . $kingdom->name);
        
        my @capital_block;
        my $capital = $kingdom->capital_city;
        if ($capital) {
            @capital_block = $self->find_capital_block($kingdom);          
        }
                
        my @towns = $kingdom->towns;
        
        foreach my $town (@towns) {
            next if $capital && $town->id == $capital->id;
            
            my $town_sector = $town->location;
         
            # Calculate adjustment based on whether town is connected to capital by claimed land
            my $capital_block_adjustment = 0;
            
            if (@capital_block) {
                if ($self->_sector_in_block({x=>$town_sector->x, y=>$town_sector->y}, @capital_block)) {
                    $capital_block_adjustment = 5;
                    #$c->logger->debug("Town " . $town->town_name . " in capital block");
                }
                else {
                    $capital_block_adjustment = -8;
                    #$c->logger->debug("Town " . $town->town_name . " not in capital block");
                }
            }
            else {
                # No capital
                $capital_block_adjustment = -3;
            }
            
            # Calculate adjustment based on distance from capital
            #  Only applied if it's in the capital block
            my $distance_to_capital_adjustment = 0;
            if ($capital_block_adjustment > 0) {
                my $distance_to_capital = RPG::Map->get_distance_between_points(
                    {
                        x => $town_sector->x,
                        y => $town_sector->y,
                    },
                    {
                        x => $capital->location->x,
                        y => $capital->location->y,
                    }
                );
                $distance_to_capital_adjustment = round(10 - ($distance_to_capital / 10));
            }
            
            my $loyalty_adjustment = $capital_block_adjustment + $distance_to_capital_adjustment;
           
            my $kingdom_town = $schema->resultset('Kingdom_Town')->find_or_create(
                {
                    kingdom_id => $kingdom->id,
                    town_id => $town->id,
                }
            );
            $kingdom_town->adjust_loyalty($loyalty_adjustment);
            $kingdom_town->update;

            $c->logger->debug("Adjusting town loyalty for town " . $town->id . " to " . $kingdom_town->loyalty . "; " . 
                "capital_block_adjustment: $capital_block_adjustment; " .
                "distance_to_capital_adjustment: $distance_to_capital_adjustment"
            );
        }  
        
        # Find land owned by Kingdom that's not connected to the capital, and make it neutral
        my @land = $schema->resultset('Land')->search(
            {
                kingdom_id => $kingdom->id,
                claimed_by_id => undef,
            }
        );
        
        if (@capital_block) {
            my $changed = 0;
            foreach my $land (@land) {
                if (! _sector_in_block({x=>$land->x, y=>$land->y}, @capital_block)) {
                    # Sector not connected to capital, roll to see if it should be made neutral
                    if (Games::Dice::Advanced->roll('1d100') <= $c->config->{chance_unconnected_sector_becomes_neutral}) {
                        $land->kingdom_id(undef);
                        $land->update;
                        $changed++;   
                    }
                }                   
            }
            
            $c->logger->debug("Changed $changed disconnected sectors to neutral");
        }    
       
    }    
}

sub find_capital_block {
    my $self = shift;
    my $kingdom = shift;
    
    my $c = $self->context;
    
    my @border_sectors = $kingdom->border_sectors(1);
    
    my %world_range = $c->schema->resultset('Land')->get_x_y_range();
    
    my %grid;
    foreach my $sector (@border_sectors) {
        $grid{$sector->{x} . ',' . $sector->{y}} = $sector;
    }
    
    my @blocks;
    while (%grid) {
        my $start_coords = _find_start(\%world_range, %grid);
        my $start_sector = delete $grid{$start_coords};
        
        #warn Dumper $start_sector;
        
        last unless $start_sector;
        
        my @block_sectors = ($start_sector);
        my $last_sector = $start_sector;
        while (my $adjacent_sector = _get_adj_sector($last_sector, %grid)) {
            delete $grid{$adjacent_sector->{x} . ',' . $adjacent_sector->{y}};
            push @block_sectors, $adjacent_sector;
            $last_sector = $adjacent_sector;   
        }
        
        push @blocks, \@block_sectors;        
    }
    
    #$c->logger->debug("Found " . scalar @blocks . " blocks in kingdom");
    
    # Find the block with the capital
    my $capital_sector = $kingdom->capital_city->location;
    foreach my $block (@blocks) {
        return @$block if $self->_sector_in_block(
            {
                x => $capital_sector->x,
                y => $capital_sector->y,
            },
            @$block,
        );
    }
}

sub _find_start {
    my $world_range = shift;
    my %grid = @_;
    
    for my $x ($world_range->{min_x} .. $world_range->{max_x}) {
        for my $y ($world_range->{min_y} .. $world_range->{max_y}) {
            return "$x,$y" if $grid{"$x,$y"};   
        }    
    } 
}

sub _get_adj_sector {
    my $current = shift;
    my %grid = @_;
    
    return $grid{($current->{x}+1).','.$current->{y}} ||
           $grid{$current->{x}.','.($current->{y}+1)} ||
           $grid{($current->{x}-1).','.$current->{y}} ||
           $grid{$current->{x}.','.($current->{y}-1)} ||
           $grid{($current->{x}+1).','.($current->{y}+1)} ||
           $grid{($current->{x}+1).','.($current->{y}-1)} ||
           $grid{($current->{x}-1).','.($current->{y}+1)} ||
           $grid{($current->{x}-1).','.($current->{y}-1)};      
}

sub _sector_in_block {
    my $self = shift;
    my $sector = shift;
    my @border_sectors = @_;
    
    my %matches;
    foreach my $border_sector (@border_sectors) {
        next unless $border_sector;
        if ($sector->{x} >= $border_sector->{x}) {
            $matches{min_x} = 1;
        }
        if ($sector->{x} <= $border_sector->{x}) {
            $matches{max_x} = 1;
        }
        if ($sector->{y} >= $border_sector->{y}) {
            $matches{min_y} = 1;
        }
        if ($sector->{y} <= $border_sector->{y}) {
            $matches{max_y} = 1;
        }
        
        return 1 if (grep { $matches{$_} } qw(min_x max_x min_y max_y)) >= 4;
    }   
}

1;
