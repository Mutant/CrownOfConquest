use strict;
use warnings;

package RPG::Schema::Dungeon_Grid;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Dungeon_Grid');

__PACKAGE__->add_columns(qw/dungeon_grid_id x y dungeon_room_id stairs_up/);

__PACKAGE__->set_primary_key('dungeon_grid_id');

__PACKAGE__->has_many(
    'doors',
    'RPG::Schema::Door',
    { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' }
);

__PACKAGE__->has_many(
    'walls',
    'RPG::Schema::Dungeon_Wall',
    { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' }
);

__PACKAGE__->belongs_to(
    'dungeon_room',
    'RPG::Schema::Dungeon_Room',
    { 'foreign.dungeon_room_id' => 'self.dungeon_room_id' }
);

__PACKAGE__->has_many(
    'mapped_dungeon_grid',
    'RPG::Schema::Mapped_Dungeon_Grid',
    { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' }
);

__PACKAGE__->might_have(
    'creature_group',
    'RPG::Schema::CreatureGroup',
    { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' }
);

sub sides_with_walls {
    my $self = shift;
    
    return @{$self->{sides_with_walls}} if defined $self->{sides_with_walls};
    
    my @walls = $self->walls;
    
    my @sides_with_walls;
    
    foreach my $wall (@walls) {
        push @sides_with_walls, $wall->position->position;
    }
    
    $self->{sides_with_walls} = \@sides_with_walls;
    
    return @sides_with_walls;    
}

sub has_wall {
    my $self = shift;
    my $wall_side = shift;
    
    return grep { $wall_side eq $_ } $self->sides_with_walls;
}

sub sides_with_doors {
    my $self = shift;
    
    return @{$self->{sides_with_doors}} if defined $self->{sides_with_doors};
    
    my @doors = $self->doors;
    
    my @sides_with_doors;
    
    foreach my $door (@doors) {
        push @sides_with_doors, $door->position->position;
    }
    
    $self->{sides_with_doors} = \@sides_with_doors;
    
    return @sides_with_doors;    
}

sub has_door {
    my $self = shift;
    my $door_side = shift;
    
    return grep { $door_side eq $_ } $self->sides_with_doors;
}


sub allowed_to_move_to_sector {
    my $self = shift;
    my $sector = shift;
        
    my $dist = RPG::Map->get_distance_between_points(
        {
            x => $self->x,
            y => $self->y,
        },
        {
            x => $sector->x,
            y => $sector->y,
        },
    );
    
    #warn "start: " . $self->x . ", " . $self->y . " dest: " . $sector->x . ", " . $sector->y . ", dist: $dist\n";
            
    # Can't move to sector if it's out of range
    if ($dist > RPG::Schema->config->{dungeon_move_maximum}) {
        return 0;
    }
    
    if ($self->dungeon_room_id != $sector->dungeon_room_id) {
        # If sectors aren't in same room, there must be a door between them, or you can't move there
        # TODO: generates too many queries, so disabled for now... can only move within the room
        #return $self->dungeon_room->connected_to_room($sector->dungeon_room_id);
        return unless RPG::Map->is_adjacent_to(
            {
                x => $self->x,
                y => $self->y,
            },
            {
                x => $sector->x,
                y => $sector->y,
            }
        );
        
        # Must have a door between them
        
        # Sector to the right
        if ($self->x < $sector->x && $self->y == $sector->y && $sector->has_door('left')) {
            return 1;
        }
        
        # Sector to the left
        if ($self->x > $sector->x && $self->y == $sector->y && $sector->has_door('right')) {
            return 1;
        }
    
        # Sector above
        if ($self->y > $sector->y && $self->x == $sector->x && $sector->has_door('bottom')) {
            return 1;
        }
        
        # Sector below
        if ($self->y < $sector->y && $self->x == $sector->x && $sector->has_door('top')) {
            return 1;
        }
        
        return 0;
        
    } 
    
    return 1;    
}

sub available_creature_group {
    my $self = shift;
    
    my $creature_group = $self->find_related('creature_group',
        {
            dungeon_grid_id => $self->id,
            'in_combat_with.party_id' => undef,
        },
        {
            prefetch => {'creatures' => ['type', 'creature_effects']},
            join => 'in_combat_with',
        }
    );
    
    return $creature_group;
}

1;