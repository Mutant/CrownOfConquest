package RPG::NewDay::Action::Town_Loyalty;

# Calculate the loyalty of towns for their kingdoms

use Moose;

extends 'RPG::NewDay::Base';

use RPG::Map;

use Data::Dumper;
use Carp;
use Math::Round qw(round);
use AI::Pathfinding::AStar::Rectangle;

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
        
        my $sectors_rs = $kingdom->sectors;
        
        $sectors_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');    
        
        my @sectors = $sectors_rs->all;
        
        my $connected_sectors = $self->_calculate_connected_sectors($kingdom, @sectors);
        
        my $capital = $kingdom->capital_city;
                
        my @towns = $kingdom->towns;
        
        foreach my $town (@towns) {
            next if $capital && $town->id == $capital->id;
            
            my $town_sector = $town->location;
         
            # Calculate adjustment based on whether town is connected to capital by claimed land
            my $capital_block_adjustment = 0;
            
            if ($capital) {
                if ($connected_sectors->{$town_sector->x}{$town_sector->y}) {
                    $capital_block_adjustment = 5;
                    $c->logger->debug("Town " . $town->town_name . " in capital block");
                }
                else {
                    $capital_block_adjustment = -8;
                    $c->logger->debug("Town " . $town->town_name . " not in capital block");
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
        
        if ($capital) {
            my $changed = 0;
            foreach my $sector (@sectors) {
                if (! $sector->{claimed_by_id} && ! $connected_sectors->{$sector->{x}}{$sector->{y}}) {
                    # Sector not connected to capital, roll to see if it should be made neutral
                    if (Games::Dice::Advanced->roll('1d100') <= $c->config->{chance_unconnected_sector_becomes_neutral}) {
                        my $land = $schema->resultset('Land')->find($sector->{land_id});
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

sub _calculate_connected_sectors {
    my $self = shift;
    my $kingdom = shift;
    my @sectors = @_;
    
    my $c = $self->context;
    
    my %size = $c->schema->resultset('Land')->get_x_y_range();
    my $map = AI::Pathfinding::AStar::Rectangle->new({height=>$size{max_x}+1, width=>$size{max_y}+1});
    foreach my $sector (@sectors) {   
        $map->set_passability($sector->{x}, $sector->{y}, 1);
    }
    
    my $capital = $kingdom->capital_city;
    
    return unless $capital;
    
    my $capital_loc = $capital->location;
    
    my $connected;
    
    foreach my $sector (@sectors) {
        if ($map->astar($capital_loc->x, $capital_loc->y, $sector->{x}, $sector->{y})) {
            $connected->{$sector->{x}}{$sector->{y}} = 1;
        }           
    }
    
    return $connected;    
}

1;
