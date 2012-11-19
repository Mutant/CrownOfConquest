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
                $capital_block_adjustment = -15;
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
                $c->logger->debug("Town is $distance_to_capital sectors from capital");
                $distance_to_capital_adjustment = round(10 - ($distance_to_capital / 5));
            }
            
            # Charisma bonus
            my $king = $kingdom->king;
            my $charisma_bonus = $king->execute_skill('Charisma', 'kingdom_loyalty') // 0;
            
            # Penalty for being a log way from other towns in kingdom
            my @nearby_towns_in_kingdom = RPG::ResultSet::RowsInSectorRange->find_in_range(
                resultset           => $c->schema->resultset('Town'),
                relationship        => 'location',
                base_point          => {
                    x => $town_sector->x,
                    y => $town_sector->y,
                },
                search_range => 35,
                increment_search_by => 0,
                rows_as_hashrefs => 1,
                criteria => {
                    'location.kingdom_id' => $kingdom->id,
                }
            );
            $c->logger->debug("Town has " . scalar @nearby_towns_in_kingdom . " nearby towns in kingdom");
            
            my $town_proximity_adjustment;
            $town_proximity_adjustment = scalar @nearby_towns_in_kingdom;
            $town_proximity_adjustment = 5 if $town_proximity_adjustment > 5;
            $town_proximity_adjustment = -15 if scalar @nearby_towns_in_kingdom <= 0;
            
            my $random = 5 - Games::Dice::Advanced->roll('1d9');
            
            my $loyalty_adjustment = $capital_block_adjustment + $distance_to_capital_adjustment + $charisma_bonus + $town_proximity_adjustment + $random;
           
            my $kingdom_town = $schema->resultset('Kingdom_Town')->find_or_create(
                {
                    kingdom_id => $kingdom->id,
                    town_id => $town->id,
                }
            );
            $kingdom_town->adjust_loyalty($loyalty_adjustment);
            $kingdom_town->update;

            $c->logger->debug("Adjusting town loyalty for town " . $town->id . " to " . $kingdom_town->loyalty . "; " . 
                "adjustment: $loyalty_adjustment. [" .
                "capital_block_adjustment: $capital_block_adjustment; " .
                "distance_to_capital_adjustment: $distance_to_capital_adjustment; " .
                "charisma_bonus: $charisma_bonus; " .
                "town_proximity_adjustment: $town_proximity_adjustment; " .
                "random: $random;]"
            );
        }
        
        if ($capital) {
            my $changed = 0;
            foreach my $sector (@sectors) {
                if (! $sector->{claimed_by_id}) {
                    # Sector is a "free" claim (not claimed by building or town), roll for going neutral
                    if (Games::Dice::Advanced->roll('1d100') <= $c->config->{chance_free_claimed_sector_becomes_neutral}) {
                        my $land = $schema->resultset('Land')->find($sector->{land_id});
                        $land->kingdom_id(undef);
                        $land->update;
                        $changed++;   
                    }
                }                   
            }
            
            $c->logger->debug("Changed $changed free claimed sectors to neutral");
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
