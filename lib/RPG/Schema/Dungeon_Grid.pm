package RPG::Schema::Dungeon_Grid;

use strict;
use warnings;

use base 'DBIx::Class';

use Carp;
use Data::Dumper;

use Clone qw(clone);

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Dungeon_Grid');

__PACKAGE__->resultset_class('RPG::ResultSet::Dungeon_Grid');

__PACKAGE__->add_columns(qw/dungeon_grid_id x y dungeon_room_id stairs_up/);

__PACKAGE__->set_primary_key('dungeon_grid_id');

__PACKAGE__->has_many( 'doors', 'RPG::Schema::Door', { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' } );

__PACKAGE__->has_many( 'walls', 'RPG::Schema::Dungeon_Wall', { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' } );

__PACKAGE__->belongs_to( 'dungeon_room', 'RPG::Schema::Dungeon_Room', { 'foreign.dungeon_room_id' => 'self.dungeon_room_id' } );

__PACKAGE__->has_many( 'mapped_dungeon_grid', 'RPG::Schema::Mapped_Dungeon_Grid', { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' } );

__PACKAGE__->might_have( 'creature_group', 'RPG::Schema::CreatureGroup', { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' } );

sub sides_with_walls {
    my $self = shift;

    return @{ $self->{sides_with_walls} } if defined $self->{sides_with_walls};

    my @walls = $self->walls;

    my @sides_with_walls;

    foreach my $wall (@walls) {
        push @sides_with_walls, $wall->position->position;
    }

    $self->{sides_with_walls} = \@sides_with_walls;

    return @sides_with_walls;
}

sub has_wall {
    my $self      = shift;
    my $wall_side = shift;

    return grep { $wall_side eq $_ } $self->sides_with_walls;
}

sub sides_with_doors {
    my $self = shift;

    return @{ $self->{sides_with_doors} } if defined $self->{sides_with_doors};

    my @doors = $self->doors;

    my @sides_with_doors;

    foreach my $door (@doors) {
        push @sides_with_doors, $door->position->position;
    }

    $self->{sides_with_doors} = \@sides_with_doors;

    return @sides_with_doors;
}

sub has_door {
    my $self      = shift;
    my $door_side = shift;

    return grep { $door_side eq $_ } $self->sides_with_doors;
}

sub allowed_to_move_to_sectors {
    my $self      = shift;
    my $sectors   = shift;
    my $max_moves = shift;

    my @sectors_to_check;

    my $allowed_to_move_to;

    # Check if sectors are greater than max move
    foreach my $sector (@$sectors) {
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

        if ($dist <= $max_moves) {
            push @sectors_to_check, $sector;
        }
        else {
            $allowed_to_move_to->[$sector->x][$sector->y] = 0;
        }
    }
    
    my $sector_grid;
    foreach my $sector (@sectors_to_check) {
        $sector_grid->[$sector->x][$sector->y] = $sector;   
    }
    
    # Check any sectors within range
    foreach my $sector (@sectors_to_check) {
        #warn "----- Checking path from " . $self->x . ", " . $self->y . " to " . $sector->x . ", " . $sector->y . "\n";
        $allowed_to_move_to->[$sector->x][$sector->y] = $self->_check_has_path($sector, $sector_grid, $max_moves);
    }
    
    return $allowed_to_move_to;
}

sub _check_has_path {
    my $self          = shift;
    my $sector        = shift;
    my $sector_grid   = shift;
    my $max_moves     = shift;
    my $moves_made    = shift;
    my $sectors_tried = shift;

    $moves_made = 0 unless defined $moves_made;

    $moves_made++;

    return 0 if $moves_made > $max_moves;

    my ( $x, $y ) = ( $sector->x, $sector->y );

    $sectors_tried->[$x][$y] = 1;

    #warn "Trying sector: $x, $y\n";

    my @paths_to_check = (
        [ $x - 1, $y - 1 ],
        [ $x + 1, $y + 1 ],
        [ $x - 1, $y + 1 ],
        [ $x + 1, $y - 1 ],
        [ $x + 1, $y ],
        [ $x - 1, $y ],
        [ $x,     $y + 1 ],
        [ $x,     $y - 1 ],
    );

    foreach my $path (@paths_to_check) {
        my ( $test_x, $test_y ) = @$path;

        #warn "Testing: $x, $y -> $test_x, $test_y (current moves: $moves_made)\n";

        if ( !$sectors_tried->[$test_x][$test_y] && $sector_grid->[$test_x][$test_y] ) {

            my $sector_to_try = $sector_grid->[$test_x][$test_y];

            #warn "Seeing if we can move there...\n";

            next unless $sector->can_move_to($sector_to_try);

            #warn "(we can)\n";

            if ( $self->x == $test_x && $self->y == $test_y ) {
                #warn ".. dest is reached";
                # Dest reached
                return 1;
            }

            if ( $self->_check_has_path( $sector_to_try, $sector_grid, $max_moves, $moves_made, clone $sectors_tried ) ) {
                #warn "... path found";
                return 1;
            }
            
            #warn ".. no path found";
        }

    }

    return 0;
}

sub can_move_to {
    my $self   = shift;
    my $sector = shift;

    #warn "in _can_move_to\n";
    #warn "src: " . $self->x . ", " . $self->y;
    #warn "dest: " . $sector->x . ", " . $sector->y;

    # Can't move to sector if src/dest are the same
    return 0 if $self->x == $sector->x && $self->y == $sector->y;

    #warn "checking is adjacent to\n";

    # Sectors must be adjacent
    return 0 unless RPG::Map->is_adjacent_to(
        {
            x => $self->x,
            y => $self->y,
        },
        {
            x => $sector->x,
            y => $sector->y,
        },
    );
    
    #warn "checking for non diagonal sectors\n";

    # Now, check walls/doors on sectors on non diagonal

    # Sector to the right
    if ( $self->x < $sector->x && $self->y == $sector->y ) {
        if ( $sector->has_wall('left') && !$sector->has_door('left') ) {
            return 0;
        }
        else {
            return 1;
        }
    }

    # Sector to the left
    if ( $self->x > $sector->x && $self->y == $sector->y ) {
        if ( $sector->has_wall('right') && !$sector->has_door('right') ) {
            return 0;
        }
        else {
            return 1;
        }
    }

    # Sector above
    if ( $self->y > $sector->y && $self->x == $sector->x ) {
        if ( $sector->has_wall('bottom') && !$sector->has_door('bottom') ) {
            return 0;
        }
        else {
            return 1;
        }
    }

    # Sector below
    if ( $self->y < $sector->y && $self->x == $sector->x ) {
        if ( $sector->has_wall('top') && !$sector->has_door('top') ) {
            return 0;
        }
        else {
            return 1;
        }
    }

    # See if the sector is on the diagonal
    my $diagonal_to_check;
    if ( $self->x > $sector->x && $self->y > $sector->y ) {
        $diagonal_to_check = 'top_left';
    }
    elsif ( $self->x < $sector->x && $self->y > $sector->y ) {
        $diagonal_to_check = 'top_right';
    }
    elsif ( $self->x > $sector->x && $self->y < $sector->y ) {
        $diagonal_to_check = 'bottom_left';
    }
    elsif ( $self->x < $sector->x && $self->y < $sector->y ) {
        $diagonal_to_check = 'bottom_right';
    }
    
    #warn "must be diagonal sector: $diagonal_to_check\n";

    # Should never happen... (!)
    croak "Couldn't find position of adjacent sector (src: " . $self->x . ", " . $self->y . "; dest: " . $sector->x . ", " . $sector->y . ")"
        unless $diagonal_to_check;

    my %diagonal_checks = (
        'top_left'     => [ 'bottom', 'right' ],
        'top_right'    => [ 'bottom', 'left' ],
        'bottom_left'  => [ 'top',    'right' ],
        'bottom_right' => [ 'top',    'left' ],
    );

    # Find the corners we're interested in for the source and dest sectors. Move can't be completed if either pair of walls exist.
    #  Exception to that is if one has a door, so long as there's not a corresponding wall on the other sector blocking it
    my ( $dest_wall_1, $dest_wall_2 ) = @{ $diagonal_checks{$diagonal_to_check} };
    my ( $src_wall_1, $src_wall_2 ) = ( RPG::Position->opposite($dest_wall_1), RPG::Position->opposite($dest_wall_2) );
    
    #warn "Dest corner: $dest_wall_1, $dest_wall_2\n";
    #warn "Src corner: $src_wall_1, $src_wall_2\n";

    my $dest_pos1_blocked = $sector->has_wall($dest_wall_1) && ( $self->has_wall($src_wall_2) || !$sector->has_door($dest_wall_1) );
    my $dest_pos2_blocked = $sector->has_wall($dest_wall_2) && ( $self->has_wall($src_wall_1) || !$sector->has_door($dest_wall_2) );
    
    return 0 if $dest_pos1_blocked && $dest_pos2_blocked;

    my $src_pos1_blocked = $self->has_wall($src_wall_1) && ( $sector->has_wall($dest_wall_2) || !$self->has_door($src_wall_1) );
    my $src_pos2_blocked = $self->has_wall($src_wall_2) && ( $sector->has_wall($dest_wall_1) || !$self->has_door($src_wall_2) );
    
    return 0 if $src_pos1_blocked && $src_pos2_blocked;
    
    # Now check if there's a horizontal or vertical blockage
    return 0 if ($self->has_wall($src_wall_1) && ! $self->has_door($src_wall_1)) && ($sector->has_wall($dest_wall_1) && ! $sector->has_door($dest_wall_1));
    return 0 if ($self->has_wall($src_wall_2) && ! $self->has_door($src_wall_2)) && ($sector->has_wall($dest_wall_2) && ! $sector->has_door($dest_wall_2)); 
    
    #warn "No blockages found\n";
    
    # Only get here if move can be completed
    return 1;

}

sub available_creature_group {
    my $self = shift;

    my $creature_group = $self->find_related(
        'creature_group',
        {
            dungeon_grid_id           => $self->id,
            'in_combat_with.party_id' => undef,
        },
        {
            prefetch => { 'creatures' => [ 'type', 'creature_effects' ] },
            join     => 'in_combat_with',
        }
    );

    return $creature_group;
}

1;
