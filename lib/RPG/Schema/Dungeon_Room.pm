use strict;
use warnings;

package RPG::Schema::Dungeon_Room;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Dungeon_Room');

__PACKAGE__->add_columns(qw/dungeon_room_id dungeon_id/);

__PACKAGE__->set_primary_key('dungeon_room_id');

__PACKAGE__->belongs_to(
    'dungeon',
    'RPG::Schema::Dungeon',
    { 'foreign.dungeon_id' => 'self.dungeon_id' }
);

__PACKAGE__->has_many(
    'sectors',
    'RPG::Schema::Dungeon_Grid',
    { 'foreign.dungeon_room_id' => 'self.dungeon_room_id' }
);

sub connected_to_room {
    my $self = shift;
    my $room_id = shift;
    
    return $self->{connected_to_room}{$room_id} if defined $self->{connected_to_room}{$room_id};
        
    return 0 if $room_id == $self->dungeon_room_id;
        
    my @sectors = $self->result_source->schema->resultset('Dungeon_Grid')->search(
        {
            dungeon_room_id => $self->id,
        },
        {
            prefetch => {'doors' => 'position'},
        }
    );
    
    my $connected = 0;

    SECTOR: foreach my $sector (@sectors) {
        foreach my $door ($sector->doors) {
            my ($sector_to_check_x, $sector_to_check_y) = RPG::Position->opposite_sector($door->position->position, $sector->x, $sector->y);
                        
            my $sector_to_check = $self->result_source->schema->resultset('Dungeon_Grid')->find(
                {
                    x => $sector_to_check_x,
                    y => $sector_to_check_y,
                    'dungeon_room.dungeon_id' => $self->dungeon_id,
                },
                {
                    join => 'dungeon_room',
                }
            );
            
            if ($sector_to_check->dungeon_room_id == $room_id) {
                $connected = 1;
                last SECTOR;
            }
        }
    }
    
    $self->{connected_to_room}{$room_id} = $connected;
    
    return $connected;
}

1;