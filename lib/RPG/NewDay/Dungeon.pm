use strict;
use warnings;

package RPG::NewDay::Dungeon;

use RPG::Map;
use Games::Dice::Advanced;
use List::Util qw(shuffle);

use Carp;
use Data::Dumper;

# TODO: refactor so we're passing this round as an object (or something). Shouldn't be using 'our' here, but makes testing possible
our ( $config, $schema, $logger, $new_day );

sub run {
    my $package = shift;
    ( $config, $schema, $logger, $new_day ) = @_;

    my $dungeons_rs = $schema->resultset('Dungeon')->search();

    my $land_rs = $schema->resultset('Land')->search(
        {},
        {
            prefetch => [ 'town', 'dungeon' ],

        }
    );

    my $ideal_dungeons = int $land_rs->count / $config->{land_per_dungeon};

    my $dungeons_to_create = 1;    #$ideal_dungeons - $dungeons_rs->count;

    $logger->info("Creating $dungeons_to_create dungeons");

    my @land = $land_rs->all;

    my $land_by_sector;
    foreach my $sector (@land) {
        $land_by_sector->[ $sector->x ][ $sector->y ] = $sector;
    }

    my $dungeons_created = [];

    my %positions = map { $_->position => $_->position_id } $schema->resultset('Dungeon_Position')->search;

    for ( 1 .. $dungeons_to_create ) {
        my $sector_to_use = $package->_find_sector_to_create( \@land, $land_by_sector, $dungeons_created );

        $dungeons_created->[ $sector_to_use->x ][ $sector_to_use->y ] = 1;

        my $dungeon = $schema->resultset('Dungeon')->create(
            {
                land_id => $sector_to_use->id,
                level   => Games::Dice::Advanced->roll( '1d' . $config->{dungeon_max_level} ),
            }
        );

        $package->_generate_dungeon_grid( $dungeon, \%positions );
    }
}

sub _find_sector_to_create {
    my $package          = shift;
    my $land             = shift;
    my $land_by_sector   = shift;
    my $dungeons_created = shift;

    my $sector_to_use;
    OUTER: foreach my $sector ( shuffle @$land ) {
        my ( $top, $bottom ) = RPG::Map->surrounds_by_range( $sector->x, $sector->y, $config->{min_distance_from_dungeon_or_town} );

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
    my $package   = shift;
    my $dungeon   = shift;
    my $positions = shift;

    my $number_of_rooms = Games::Dice::Advanced->roll( $dungeon->level + 1 . 'd20' ) + 20;

    my @doors_to_join;

    my $sectors_created;

    $logger->debug("Creating $number_of_rooms rooms in dungeon");

    for my $current_room_number ( 1 .. $number_of_rooms ) {
        $logger->debug("Creating room # $current_room_number");

        $logger->debug( scalar @doors_to_join . " doors left to join" );

        my ( $start_x, $start_y );

        my $door_to_join;

        if ( $current_room_number == 1 ) {

            # Pick a spot for the first room
            $start_x = 1;
            $start_y = 1;
        }
        else {
            # Find a door to join
            if (scalar @doors_to_join == 0) {
                # If there are no doors to join, create some more
                my @sectors;
                foreach my $sector_array (@$sectors_created) {
                    push @sectors, map { $_ } @$sector_array;
                }
                
                my ($new_door, $joined);
                
                while (! $door_to_join || $joined) {
                    ( $door_to_join, $joined ) = $package->_create_door( \@sectors, $sectors_created, $positions );
                }
            }
            else {            
                @doors_to_join = shuffle @doors_to_join;
                $door_to_join  = shift @doors_to_join;
            }

            $logger->debug( "Joining to door at: " . $door_to_join->dungeon_grid->x . ", " . $door_to_join->dungeon_grid->y . ": " . $door_to_join->position->position );

            ( $start_x, $start_y ) = $door_to_join->opposite_sector;
        }

        $logger->debug("Creating room with start pos of $start_x, $start_y");

        # Create the room
        my @new_sectors = $package->_create_room( $dungeon, $start_x, $start_y, $sectors_created, $positions );

        # Keep track of sectors created
        foreach my $new_sector (@new_sectors) {
            $sectors_created->[ $new_sector->x ][ $new_sector->y ] = $new_sector;
        }

        # Create other side of door to join
        if ($door_to_join) {
            #$logger->debug("Creating other side of door to join at $");
            
            my $position = $schema->resultset('Dungeon_Position')->find( { position => $door_to_join->opposite_position }, );

            my $door = $schema->resultset('Door')->create(
                {
                    position_id     => $position->id,
                    dungeon_grid_id => $sectors_created->[$start_x][$start_y]->id,
                }
            );
        }

        # Create doors
        unless ( $current_room_number == $number_of_rooms ) {
            my $doors_to_create = Games::Dice::Advanced->roll('1d4') - 1;
            $doors_to_create++ unless @doors_to_join;

            $logger->debug("Creating $doors_to_create doors");

            for ( 1 .. $doors_to_create ) {
                my ( $door, $joined ) = $package->_create_door( \@new_sectors, $sectors_created, $positions );

                last unless $door;

                push @doors_to_join, $door if !$joined;
            }
        }
        else {
            $logger->debug( "Deleting " . scalar @doors_to_join );

            # Delete doors to nowhere
            foreach my $door (@doors_to_join) {
                $door->delete;
            }
        }

    }
}

sub _create_room {
    my $package         = shift;
    my $dungeon         = shift;
    my $start_x         = shift;
    my $start_y         = shift;
    my $sectors_created = shift;
    my $positions       = shift;

    my ( $top_x, $top_y, $x_size, $y_size ) = $package->_find_room_dimensions( $start_x, $start_y );
    my $bottom_x = $top_x + $x_size - 1;
    my $bottom_y = $top_y + $y_size - 1;

    #warn "$top_x, $top_y, $bottom_x, $bottom_y\n";
    #warn Dumper $sectors_created;

    my @sectors;

    for my $x ( $top_x .. $bottom_x ) {
        for my $y ( $top_y .. $bottom_y ) {
            next if $sectors_created->[$x][$y];

            my $sector = $schema->resultset('Dungeon_Grid')->create(
                {
                    x          => $x,
                    y          => $y,
                    dungeon_id => $dungeon->id,
                }
            );

            my @walls_to_create;
            if ( $x == $top_x || ($sectors_created->[ $x-1 ][ $y ] && $sectors_created->[ $x-1 ][ $y ]->has_wall('right')) ) {
                push @walls_to_create, 'left';
            }
            if ( $x == $bottom_x || ($sectors_created->[ $x+1 ][ $y ] && $sectors_created->[ $x+1 ][ $y ]->has_wall('left')) ) {
                push @walls_to_create, 'right';
            }
            if ( $y == $top_y || ($sectors_created->[ $x ][ $y-1 ] && $sectors_created->[ $x ][ $y-1 ]->has_wall('bottom')) ) {
                push @walls_to_create, 'top';
            }
            if ( $y == $bottom_y || ($sectors_created->[ $x ][ $y+1 ] && $sectors_created->[ $x ][ $y+1 ]->has_wall('top')) ) {
                push @walls_to_create, 'bottom';
            }

            foreach my $wall (@walls_to_create) {
                $schema->resultset('Dungeon_Wall')->create(
                    {
                        dungeon_grid_id => $sector->id,
                        position_id     => $positions->{$wall}
                    }
                );
            }

            push @sectors, $sector;
        }
    }

    return @sectors;

}

sub _find_room_dimensions {
    my $package = shift;
    my $start_x = shift;
    my $start_y = shift;

    my $x_size = Games::Dice::Advanced->roll( '1d' . $config->{max_x_dungeon_room_size} );
    my $y_size = Games::Dice::Advanced->roll( '1d' . $config->{max_y_dungeon_room_size} );

    my $top_x = Games::Dice::Advanced->roll( '1d' . $x_size ) + $start_x - $x_size;
    my $top_y = Games::Dice::Advanced->roll( '1d' . $y_size ) + $start_y - $y_size;

    $top_x = 1 if $top_x < 1;
    $top_y = 1 if $top_y < 1;

    return ( $top_x, $top_y, $x_size, $y_size );

}

sub _create_door {
    my $package              = shift;
    my $sectors_to_create_in = shift;
    my $existing_sectors     = shift;
    my $positions            = shift;
    
    my $sector_to_create_in;
    my $position;
    foreach my $sector ( shuffle @$sectors_to_create_in ) {
        next unless $sector;
        if ( my @wall_positions = $sector->sides_with_walls ) {
            my @doors = $sector->doors;

            my @possible_positions;
            foreach my $wall_pos (@wall_positions) {
                next if $wall_pos eq 'left' && $sector->x == 1;
                next if $wall_pos eq 'top' && $sector->y == 1;
                
                next if grep { $_->position->position eq $wall_pos } @doors;
                
                push @possible_positions, $wall_pos;                
            };

            $position = ( shuffle @possible_positions )[0];

            next unless $position;

            $sector_to_create_in = $sector;
            last;
        }
    }

    return unless $sector_to_create_in;

    $logger->debug( "Creating door at " . $sector_to_create_in->x . ", " . $sector_to_create_in->y );

    my $door = $schema->resultset('Door')->create(
        {
            dungeon_grid_id => $sector_to_create_in->id,
            position_id     => $positions->{$position},
        }
    );

    # See if there's a sector joining into this door. If so, create a door there
    my $adjacent_room = 0;

    my ( $opposite_door_x, $opposite_door_y ) = $door->opposite_sector;
    
    if ( my $adjacent_sector = $existing_sectors->[ $opposite_door_x ][ $opposite_door_y ] ) {
        $adjacent_room = 1;

        my @doors             = $adjacent_sector->doors;
        my $opposite_position = $door->opposite_position;

        unless ( grep { $_ eq $opposite_position } @doors ) {

            # There's not already a door joined, so create one
            $schema->resultset('Door')->create(
                {
                    dungeon_grid_id => $adjacent_sector->id,
                    position_id     => $positions->{$opposite_position},
                }
            );
        }
    }

    return ( $door, $adjacent_room );
}

1;
