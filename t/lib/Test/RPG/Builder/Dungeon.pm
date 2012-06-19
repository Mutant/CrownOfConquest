use strict;
use warnings;

package Test::RPG::Builder::Dungeon;

use Test::RPG::Builder::Dungeon_Room;

sub build_dungeon {
    my $package = shift;
    my $schema = shift;
    my %params = @_;
    
    unless ($params{land_id}) {
        my $location = $schema->resultset('Land')->create( {} );
        $params{land_id} = $location->id;
    }
    
    my $dungeon = $schema->resultset('Dungeon')->create(
        {
            land_id => $params{land_id},
            level => $params{level} || 1,
            type => $params{type} || 'dungeon',            
        }   
    );
    
    if ($params{rooms}) {
        for my $count (1..$params{rooms}) {
            my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($schema,
                dungeon_id => $dungeon->id,
                top_left => {
                    x => $count,
                    y => $count,
                },
                bottom_right => {
                    x => $count,
                    y => $count,
                },
                create_walls => 1,
            )
        }   
    }
    
    return $dungeon;    	
}

1;
