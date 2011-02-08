package RPG::NewDay::Action::Dungeon_Special_Rooms;

use Moose;

extends 'RPG::NewDay::Base';

use Math::Round qw(round);
use List::Util qw(shuffle);
use Games::Dice::Advanced;

use RPG::Map;

use feature 'switch';

sub depends { qw/RPG::NewDay::Action::Dungeon/ };

sub run {
    my $self = shift;
    
    my $c = $self->context;
    
    my $dungeons_rs = $c->schema->resultset('Dungeon')->search(
    	{
    		type => 'dungeon',
    	}
    );
    
    while (my $dungeon = $dungeons_rs->next) {
        $self->delete_special_rooms($dungeon);
        
        my $room_count = $dungeon->rooms->count;
            
        $c->logger->debug("Dungeon " . $dungeon->id . " has $room_count rooms");
            
        my $special_room_count = $dungeon->search_related(
            'rooms',
            {
                special_room_id => {'!=', undef},
            },
        )->count;
           
        my $special_rooms_to_have = round($room_count * ($c->config->{dungeon_special_room_percentage} / 100));
        if ($special_rooms_to_have < 1 && $special_room_count < 1) {
            # Chance of smaller dungeons getting a special room
            $special_rooms_to_have = 1 if Games::Dice::Advanced->roll('1d100') <= 35;
        }
       
        $c->logger->debug("Want $special_rooms_to_have special rooms in dungeon " . $dungeon->id . ", have $special_room_count");
        
        if ($special_room_count < $special_rooms_to_have) {
            $self->generate_special_rooms($dungeon, $special_rooms_to_have - $special_room_count);   
        }
    }
}

sub generate_special_rooms {
    my $self = shift;
    my $dungeon = shift;
    my $room_count = shift;
    
    my $c = $self->context;
    
    my @room_types = $c->schema->resultset('Dungeon_Special_Room')->search();
    my $floor_count = $dungeon->floor_count;
    
    for (1..$room_count) {
        # Find a room to use
        my $floor_to_use = $floor_count;
        if ($floor_count >= 3) {
           $floor_to_use = (shuffle 2..$floor_count)[0];
        }
    
        $c->logger->debug("Using floor $floor_to_use to generate special room");
       
        # Find stairs up sector
        my $stairs_sector = $c->schema->resultset('Dungeon_Grid')->find(
            {
                'dungeon_room.dungeon_id' => $dungeon->id,
                'dungeon_room.floor' => $floor_to_use,
                'stairs_up' => 1,
                
            },
            {
                'join' => 'dungeon_room',
            }        
        );
        
        return unless $stairs_sector;
        
        my $stairs_coord = {
            x => $stairs_sector->x,
            y => $stairs_sector->y,        
        };
        
        # Find floor dimensions
        my $floor_dimensions = $dungeon->get_coord_range_of_floor($floor_to_use);
        
        # Get minimum range from stairs
        my $dist_from_top_left = RPG::Map->get_distance_between_points(
            $floor_dimensions->[0],
            $stairs_coord,
        );
        
        my $dist_from_bottom_right = RPG::Map->get_distance_between_points(
            $floor_dimensions->[1],
            $stairs_coord,
        );
        
        my $min_dist_from_stairs_allowed = ($dist_from_top_left > $dist_from_bottom_right ? $dist_from_top_left : $dist_from_bottom_right) - 5;
        $min_dist_from_stairs_allowed = 5 if $min_dist_from_stairs_allowed < 5;
    
        # Query all sectors in the floor
        my $sectors_in_floor_rs = $c->schema->resultset('Dungeon_Grid')->search(
            {
                'dungeon_room.dungeon_id' => $dungeon->id,
                'dungeon_room.floor' => $floor_to_use,
            },
            {
                'join' => 'dungeon_room',
                'order_by' => \'rand()',
            }
        );
        
        my $room_to_use;
        # Find a room with a sector min distance from stairs, without a special room, and at least 4 sectors in size
        while (my $sector = $sectors_in_floor_rs->next) {
            my $dist = RPG::Map->get_distance_between_points(
                {
                    x => $sector->x,
                    y => $sector->y,
                },
                $stairs_coord,
            );
            
            next unless $dist >= $min_dist_from_stairs_allowed;
            
            my $room = $sector->dungeon_room;
            
            next if $room->special_room_id;
            
            next unless $room->sectors->count >= 4;
            
            $room_to_use = $room;
        }
        
        return unless $room_to_use;
              
        $c->logger->debug("Using room " . $room_to_use->id);
        
        my $room_type = (shuffle @room_types)[0];
   
        $room_to_use->make_special($room_type);
    }   
}

sub delete_special_rooms {
    my $self = shift;
    my $dungeon = shift;
    
    if (Games::Dice::Advanced->roll('1d100') <= 15) {
        my @special_rooms = $dungeon->search_related('rooms',
            {
                special_room_id => {'!=', undef},
            },
        );
        
        return unless @special_rooms;
        
        my $room_to_delete = (shuffle @special_rooms)[0];
        
        $room_to_delete->remove_special;               
    } 
}

1;