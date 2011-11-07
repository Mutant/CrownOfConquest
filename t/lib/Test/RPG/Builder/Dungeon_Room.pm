use strict;
use warnings;

package Test::RPG::Builder::Dungeon_Room;

use Carp;

use Test::RPG::Builder::Dungeon_Grid;

sub build_dungeon_room {
    my $self = shift;
    my $schema = shift;
    my %params = @_;
    
    my $special_room_id;
    if ($params{special_room_type}) {
        my $special_room = $schema->resultset('Dungeon_Special_Room')->find(
            {
                room_type => $params{special_room_type},
            }
        );
        
        confess "Can't find special room type $params{special_room_type} in db" unless $special_room;
        $special_room_id = $special_room->id;
    }
    
    
    my $room = $schema->resultset('Dungeon_Room')->create({
    	dungeon_id => $params{dungeon_id} // 1,
    	floor => $params{floor} // 1,
    	special_room_id => $special_room_id,
    });
    
    my $stairs_made = 0;
    
    if ($params{x_size} && $params{'y_size'}) {
        $params{top_left} = {
            'x' => 1,
            'y' => 1,
        };
        $params{bottom_right} = {
            'x' => $params{x_size},
            'y' => $params{'y_size'},
        };
    }
    
    # Size parameters can be specified to create some dungeon sectors
    if ($params{top_left} && $params{bottom_right}) {
        for my $x ($params{top_left}{x} .. $params{bottom_right}{x}) {
            for my $y ($params{top_left}{y} .. $params{bottom_right}{y}) {
            	my %grid_params = (dungeon_room_id => $room->id, x=> $x, y => $y);

            	my @walls;       
       			# If create_walls is true, the room will have exterior walls
            	if ($params{create_walls}) {
            		if ($x == $params{top_left}{x}) {
            			push @walls, 'left';
            		}
            		if ($y == $params{top_left}{y}) {
            			push @walls, 'top';	
            		}
            		if ($x == $params{bottom_right}{x}) {
            			push @walls, 'right';
            		}
            		if ($y == $params{bottom_right}{y}) {
            			push @walls, 'bottom';	
            		}
           		
            	}
            	
            	# Additionally, a 'sector_walls' hash can be specified, to indiciate sectors that should
            	#  have walls
            	if (my $wall_spec = $params{sector_walls}{"$x,$y"}) {
            		my $walls = ref $wall_spec ? $wall_spec : [$wall_spec];
            		
            		push @walls, @$walls; 	
            	}

            	$grid_params{walls} = \@walls;
            	            	
            	# Finally, dungeon_doors can also be generated per sector
            	my @doors;
				if (my $door_spec = $params{sector_doors}{"$x,$y"}) {
            		my $doors = ref $door_spec ? $door_spec : [$door_spec];
            		
            		push @doors, @$doors; 	
            	}
            	
            	$grid_params{doors} = \@doors;
            	
            	if (! $stairs_made && $params{make_stairs}) {
            	   $grid_params{stairs_up} = 1;
            	   $stairs_made = 1;            	   
            	}
            	
                Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid($schema, %grid_params);
            }
        }   
    }
    
    return $room;
       
}

1;