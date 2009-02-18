package RPG::NewDay::Action::Dungeon;

use Mouse;

extends 'RPG::NewDay::Base';

use RPG::Map;
use Games::Dice::Advanced;
use List::Util qw(shuffle);

use Carp;
use Data::Dumper;

sub run {
    my $self = shift;

    my $c = $self->context;

    my $dungeons_rs = $c->schema->resultset('Dungeon')->search();

    my $land_rs = $c->schema->resultset('Land')->search(
        {},
        {
            prefetch => [ 'town', 'dungeon' ],

        }
    );

    my $ideal_dungeons = int $land_rs->count / $c->config->{land_per_dungeon};

    my $dungeons_to_create = $ideal_dungeons - $dungeons_rs->count;

    $c->logger->info("Creating $dungeons_to_create dungeons");

    my @land = $land_rs->all;

    my $land_by_sector;
    foreach my $sector (@land) {
        $land_by_sector->[ $sector->x ][ $sector->y ] = $sector;
    }

    my $dungeons_created = [];

    my %positions = map { $_->position => $_->position_id } $c->schema->resultset('Dungeon_Position')->search;

    for ( 1 .. $dungeons_to_create ) {
        my $sector_to_use = $self->_find_sector_to_create( \@land, $land_by_sector, $dungeons_created );

        $dungeons_created->[ $sector_to_use->x ][ $sector_to_use->y ] = 1;

        my $dungeon = $c->schema->resultset('Dungeon')->create(
            {
                land_id => $sector_to_use->id,
                level   => Games::Dice::Advanced->roll( '1d' . $c->config->{dungeon_max_level} ),
            }
        );

        $self->_generate_dungeon_grid( $dungeon, \%positions );
    }
}

sub _find_sector_to_create {
    my $self             = shift;
    my $land             = shift;
    my $land_by_sector   = shift;
    my $dungeons_created = shift;

    my $c = $self->context;

    my $sector_to_use;
    OUTER: foreach my $sector ( shuffle @$land ) {
        my ( $top, $bottom ) = RPG::Map->surrounds_by_range( $sector->x, $sector->y, $c->config->{min_distance_from_dungeon_or_town} );

        #warn Dumper $top;
        #warn Dumper $bottom;

        for my $x ( $top->{x} .. $bottom->{x} ) {
            for my $y ( $top->{y} .. $bottom->{y} ) {
                if ( $dungeons_created->[$x][$y]
                    || ( $land_by_sector->[$x][$y] && ( $land_by_sector->[$x][$y]->town || $land_by_sector->[$x][$y]->dungeon ) ) )
                {
                    next OUTER;
                }
            }
        }

        # If we get here, the sector must be ok
        $sector_to_use = $sector;
        last;
    }

    croak "Couldn't find sector to return" unless $sector_to_use;

    return $sector_to_use;
}

sub _generate_dungeon_grid {
    my $self      = shift;
    my $dungeon   = shift;
    my $positions = shift;

    my $c = $self->context;

    my $number_of_rooms = Games::Dice::Advanced->roll( $dungeon->level + 1 . 'd20' ) + 20;

    my $sectors_created;

    $c->logger->debug("Creating $number_of_rooms rooms in dungeon");

    for my $current_room_number ( 1 .. $number_of_rooms ) {
        $c->logger->debug("Creating room # $current_room_number");

        my ( $start_x, $start_y );

        my $wall_to_join;

        if ( $current_room_number == 1 ) {

            # Pick a spot for the first room
            $start_x = 15;
            $start_y = 15;
        }
        else {

            # Find a wall to join
            $wall_to_join = $self->_find_wall_to_join($sectors_created);

            $c->logger->debug( "Joining wall at "
                    . $wall_to_join->dungeon_grid->x . ", "
                    . $wall_to_join->dungeon_grid->y
                    . " position: "
                    . $wall_to_join->position->position );

            ( $start_x, $start_y ) = $wall_to_join->opposite_sector;

            # Create existing side of the door
            my $door = $c->schema->resultset('Door')->create(
                {
                    position_id     => $wall_to_join->position_id,
                    dungeon_grid_id => $wall_to_join->dungeon_grid_id,
                }
            );
        }

        $c->logger->debug("Creating room with start pos of $start_x, $start_y");

        # Create the room
        my @new_sectors = $self->_create_room( $dungeon, $start_x, $start_y, $sectors_created, $positions );

        # Create the stairs if this is the first room
        if ( $current_room_number == 1 ) {
            my $sector_for_stairs = ( shuffle @new_sectors )[0];

            $sector_for_stairs->stairs_up(1);
            $sector_for_stairs->update;
        }

        # Keep track of sectors and rooms created
        foreach my $new_sector (@new_sectors) {
            $sectors_created->[ $new_sector->x ][ $new_sector->y ] = $new_sector;
        }

        # Create other side of door to join
        if ($wall_to_join) {
            my $door = $c->schema->resultset('Door')->create(
                {
                    position_id     => $positions->{ $wall_to_join->opposite_position },
                    dungeon_grid_id => $sectors_created->[$start_x][$start_y]->id,
                }
            );
        }
    }
}

sub _create_room {
    my $self            = shift;
    my $dungeon         = shift;
    my $start_x         = shift;
    my $start_y         = shift;
    my $sectors_created = shift;
    my $positions       = shift;

    my $c = $self->context;

    my ( $top_x, $top_y, $x_size, $y_size ) = $self->_find_room_dimensions( $start_x, $start_y );
    my $bottom_x = $top_x + $x_size - 1;
    my $bottom_y = $top_y + $y_size - 1;

    #warn "$top_x, $top_y, $bottom_x, $bottom_y\n";
    #warn Dumper $sectors_created;

    my $room = $c->schema->resultset('Dungeon_Room')->create( { dungeon_id => $dungeon->id, } );

    my $coords_created;
    my @sectors;

    for my $x ( $top_x .. $bottom_x ) {
        for my $y ( $top_y .. $bottom_y ) {
            next if $sectors_created->[$x][$y];

            my $sector = $c->schema->resultset('Dungeon_Grid')->create(
                {
                    x               => $x,
                    y               => $y,
                    dungeon_room_id => $room->id,
                }
            );

            my @walls_to_create;
            if ( $x == $top_x || ( $sectors_created->[ $x - 1 ][$y] && $sectors_created->[ $x - 1 ][$y]->has_wall('right') ) ) {
                push @walls_to_create, 'left';
            }
            if ( $x == $bottom_x || ( $sectors_created->[ $x + 1 ][$y] && $sectors_created->[ $x + 1 ][$y]->has_wall('left') ) ) {
                push @walls_to_create, 'right';
            }
            if ( $y == $top_y || ( $sectors_created->[$x][ $y - 1 ] && $sectors_created->[$x][ $y - 1 ]->has_wall('bottom') ) ) {
                push @walls_to_create, 'top';
            }
            if ( $y == $bottom_y || ( $sectors_created->[$x][ $y + 1 ] && $sectors_created->[$x][ $y + 1 ]->has_wall('top') ) ) {
                push @walls_to_create, 'bottom';
            }

            foreach my $wall (@walls_to_create) {
                $c->schema->resultset('Dungeon_Wall')->create(
                    {
                        dungeon_grid_id => $sector->id,
                        position_id     => $positions->{$wall}
                    }
                );
            }

            push @sectors, $sector;
            $coords_created->[ $sector->x ][ $sector->y ] = 1;
        }
    }

    # Check for any non-contiguous sectors, and remove them
    my @contiguous_sectors;
    foreach my $sector (@sectors) {
        my $path_available =
            $self->_has_available_path( $start_x, $start_y, $sector->x, $sector->y, $top_x, $top_y, $bottom_x, $bottom_y, $coords_created, );

        # No path to start sector found, so delete it
        unless ($path_available) {
            $c->logger->debug( "Sector " . $sector->x . ", " . $sector->y . " is not contiguous with $start_x, $start_y, so removing it" );
            $sector->delete;
        }
        else {
            push @contiguous_sectors, $sector;
        }
    }

    return @contiguous_sectors;
}

sub _has_available_path {
    my $self             = shift;
    my $dest_x           = shift;
    my $dest_y           = shift;
    my $x                = shift;
    my $y                = shift;
    my $top_x            = shift;
    my $top_y            = shift;
    my $bottom_x         = shift;
    my $bottom_y         = shift;
    my $coords_available = shift;
    my $checked          = shift;

    #warn Dumper $coords_available;
    #warn Dumper $checked;

    return 1 if $dest_x == $x && $dest_y == $y;

    my @paths_to_check = ( [ $x + 1, $y ], [ $x - 1, $y ], [ $x, $y + 1 ], [ $x, $y - 1 ], );

    my $path_available = 0;
    foreach my $path (@paths_to_check) {
        my ( $test_x, $test_y ) = @$path;

        next if $test_x < $top_x || $test_y < $top_y || $test_x > $bottom_x || $test_y > $bottom_y;

        #warn "Checking path: $test_x, $test_y\n";

        if ( $dest_x == $test_x && $dest_y == $test_y ) {

            # Dest reached
            return 1;
        }

        #warn "Checked: " . ($checked->[$test_x][$test_y] || 0) . "\n";
        #warn "Avail: " . $coords_available->[$test_x][$test_y] . "\n";

        if ( !$checked->[$test_x][$test_y] && $coords_available->[$test_x][$test_y] ) {

            $checked->[$test_x][$test_y] = 1;

            if (
                $self->_has_available_path(
                    $dest_x, $dest_y, $test_x, $test_y, $top_x, $top_y, $bottom_x, $bottom_y, $coords_available, $checked
                )
                )
            {
                $path_available = 1;
                last;
            }
        }
    }

    return $path_available;

}

sub _find_room_dimensions {
    my $self    = shift;
    my $start_x = shift;
    my $start_y = shift;

    my $c = $self->context;

    my $x_size = Games::Dice::Advanced->roll( '1d' . $c->config->{max_x_dungeon_room_size} );
    my $y_size = Games::Dice::Advanced->roll( '1d' . $c->config->{max_y_dungeon_room_size} );

    my $top_x = Games::Dice::Advanced->roll( '1d' . $x_size ) + $start_x - $x_size;
    my $top_y = Games::Dice::Advanced->roll( '1d' . $y_size ) + $start_y - $y_size;

    $top_x = 1 if $top_x < 1;
    $top_y = 1 if $top_y < 1;

    return ( $top_x, $top_y, $x_size, $y_size );

}

sub _find_wall_to_join {
    my $self            = shift;
    my $sectors_created = shift;

    my $c = $self->context;

    my @all_sectors;
    foreach my $y_line (@$sectors_created) {
        foreach my $sector (@$y_line) {
            next unless defined $sector;
            push @all_sectors, $sector;
        }
    }

    my $wall_to_join;
    SECTOR: foreach my $sector ( shuffle @all_sectors ) {
        if ( my @walls = $sector->walls ) {
            foreach my $wall ( shuffle @walls ) {
                my ( $opp_x, $opp_y ) = $wall->opposite_sector;

                next if $opp_x < 1 || $opp_y < 1;

                unless ( $sectors_created->[$opp_x][$opp_y] ) {

                    # Check there's no existing door
                    my $existing_door = $c->schema->resultset('Door')->find(
                        {
                            'dungeon_grid.x' => $sector->x,
                            'dungeon_grid.y' => $sector->x,
                            position_id      => $wall->position_id,
                        },
                        { 'join' => 'dungeon_grid', }
                    );

                    unless ($existing_door) {
                        $wall_to_join = $wall;
                        last SECTOR;
                    }
                }
            }
        }
    }

    unless ($wall_to_join) {
        croak "Couldn't find a wall to join";
    }

    return $wall_to_join;

}

1;
