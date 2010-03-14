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
                Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid($schema, dungeon_room_id => $room->id, x=> $x, y => $y);
            }
        }   
    }
    
    return $room;
       
}

1;