use strict;
use warnings;

package Test::RPG::Builder::Dungeon_Room;

use Test::RPG::Builder::Dungeon_Grid;

sub build_dungeon_room {
    my $self = shift;
    my $schema = shift;
    my %params = @_;
    
    my $room = $schema->resultset('Dungeon_Room')->create({
    	dungeon_id => $params{dungeon_id} || 1,
    });
    
    if ($params{top_left} && $params{bottom_right}) {
        for my $x ($params{top_left}{x} .. $params{bottom_right}{x}) {
            for my $y ($params{top_left}{y} .. $params{bottom_right}{y}) {
            	my %grid_params = (dungeon_room_id => $room->id, x=> $x, y => $y);
            	
            	if ($params{create_walls}) {
            		my @walls;
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
            		
            		$grid_params{walls} = \@walls;
            	}
            	
                Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid($schema, %grid_params);
            }
        }   
    }
    
    return $room;
       
}

1;