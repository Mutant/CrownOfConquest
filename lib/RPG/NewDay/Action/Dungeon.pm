package RPG::NewDay::Action::Dungeon;

use Moose;

extends 'RPG::NewDay::Base';

use RPG::Map;
use RPG::Maths;
use Games::Dice::Advanced;
use List::Util qw(shuffle);
use Clone qw(clone);

use Carp qw(confess croak);
use Data::Dumper;

use feature 'switch';

my @alternative_door_types = qw/stuck locked sealed secret/;

sub run {
    my $self = shift;

    $self->check_for_dungeon_deletion();

    $self->reconfigure_doors();

    my $c = $self->context;

    my $dungeons_rs = $c->schema->resultset('Dungeon')->search();
    
    # Fill empty dungeon chests
    $self->fill_empty_chests();

    my $land_rs = $c->schema->resultset('Land')->search(
        {},
        {
            prefetch => [ 'town', 'dungeon' ],

        }
    );

    my $ideal_dungeons = int $land_rs->count / $c->config->{land_per_dungeon};

    my $dungeons_to_create = $ideal_dungeons - $dungeons_rs->count;

    $c->logger->info("Creating $dungeons_to_create dungeons");

    return if $dungeons_to_create < 1;

    my @land = $land_rs->all;

    my $land_by_sector;
    foreach my $sector (@land) {
        $land_by_sector->[ $sector->x ][ $sector->y ] = $sector;
    }

    my $dungeons_created = [];

    my %positions = map { $_->position => $_->position_id } $c->schema->resultset('Dungeon_Position')->search;

    for ( 1 .. $dungeons_to_create ) {
        my $sector_to_use;
        eval { $sector_to_use = $self->_find_sector_to_create( \@land, $land_by_sector, $dungeons_created ); };
        if ($@) {
            if ( $@ =~ /Couldn't find sector to return/ ) {
                $c->logger->warning("Couldn't find a sector to create more dungeons - not enough space");
                last;
            }
            else {
                die $@;
            }
        }

        $dungeons_created->[ $sector_to_use->x ][ $sector_to_use->y ] = 1;

        my $dungeon = $c->schema->resultset('Dungeon')->create(
            {
                land_id => $sector_to_use->id,
                level   => RPG::Maths->weighted_random_number( 1 .. $c->config->{dungeon_max_level} ),
            }
        );

        $self->_generate_dungeon_grid( $dungeon, \%positions );
        $self->generate_treasure_chests( $dungeon );
        $self->populate_sector_paths( $dungeon ); 
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
        my $door_type = 'standard';

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
            if ( Games::Dice::Advanced->roll('1d100') <= 15 ) {
                $door_type = ( shuffle(@alternative_door_types) )[0];
            }

            my $door = $c->schema->resultset('Door')->create(
                {
                    position_id     => $wall_to_join->position_id,
                    dungeon_grid_id => $wall_to_join->dungeon_grid_id,
                    type            => $door_type,
                }
            );
        }

        $c->logger->debug("Creating room with start pos of $start_x, $start_y");

        # Create the room or corridor
        my @new_sectors;
        my $corridor_roll = Games::Dice::Advanced->roll('1d100');
        if ( $corridor_roll <= 15 ) {
            @new_sectors = $self->_create_corridor( $dungeon, $start_x, $start_y, $sectors_created, $positions );
        }
        else {
            @new_sectors = $self->_create_room( $dungeon, $start_x, $start_y, $sectors_created, $positions );
        }

        croak "No new sectors returned when creating room at $start_x, $start_y" unless @new_sectors;

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
                    type            => $door_type,
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

            # TODO: replace this with _create_walls_for_room()
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

sub _create_corridor {
    my $self            = shift;
    my $dungeon         = shift;
    my $start_x         = shift;
    my $start_y         = shift;
    my $sectors_created = shift;
    my $positions       = shift;

    my $c = $self->context;

    my $room = $c->schema->resultset('Dungeon_Room')->create( { dungeon_id => $dungeon->id, } );

    my $corridor_size = Games::Dice::Advanced->roll('1d12') + 8;

    $c->logger->info("Creating corridor of size: $corridor_size");

    my $current_length = 0;

    my @directions = qw(left right top bottom);

    my ( $next_x, $next_y ) = ( $start_x, $start_y );

    my @created_sectors;
    my $coords_used;

    OUTER: while ( $current_length < $corridor_size ) {
        my $current_direction = ( shuffle(@directions) )[0];

        #$c->logger->debug("Current direction: $current_direction");

        my $direction_length = Games::Dice::Advanced->roll('1d5') + 5;
        my $length_left      = $corridor_size - $current_length;
        $direction_length = $length_left if $direction_length > $length_left;

        #$c->logger->debug("Direction length: $direction_length");

        for ( 1 .. $direction_length ) {
            if ( !$coords_used->[$next_x][$next_y] ) {
                my $sector = $c->schema->resultset('Dungeon_Grid')->create(
                    {
                        x               => $next_x,
                        y               => $next_y,
                        dungeon_room_id => $room->id,
                    }
                );

                push @created_sectors, $sector;
                $coords_used->[$next_x][$next_y] = 1;
            }

            #$c->logger->debug("Created sector at: $next_x, $next_y");

            ( $current_direction, $next_x, $next_y ) =
                $self->_find_next_corridor_direction( $current_direction, $next_x, $next_y, $sectors_created, shuffle @directions );

            if ( !$current_direction ) {
                $c->logger->info("Run out of room creating corridor");
                last OUTER;
            }

            $current_length++;

        }
    }

    $self->_create_walls_for_room( $positions, @created_sectors );

    $c->logger->info( "Final corridor size: " . scalar @created_sectors );

    return @created_sectors;

}

sub _create_walls_for_room {
    my $self      = shift;
    my $positions = shift;
    my @sectors   = @_;      # We assume the sectors passed in are all from the room we're creating walls for

    my $c = $self->context;

    my $coords;
    foreach my $sector (@sectors) {
        $coords->[ $sector->x ][ $sector->y ] = 1;
    }

    foreach my $sector (@sectors) {
        my @walls_to_create;

        # Create walls next to any sector that doesn't have an adjacent sector in this room
        unless ( $coords->[ $sector->x - 1 ][ $sector->y ] ) {
            push @walls_to_create, 'left';
        }
        unless ( $coords->[ $sector->x + 1 ][ $sector->y ] ) {
            push @walls_to_create, 'right';
        }
        unless ( $coords->[ $sector->x ][ $sector->y - 1 ] ) {
            push @walls_to_create, 'top';
        }
        unless ( $coords->[ $sector->x ][ $sector->y + 1 ] ) {
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
    }
}

sub _find_next_corridor_direction {
    my $self              = shift;
    my $current_direction = shift;
    my $next_x            = shift;
    my $next_y            = shift;
    my $sectors_created   = shift;
    my @directions        = @_;

#$self->context->logger->debug("Finding next corridor direction, current: $current_direction, x: $next_x, y: $next_x, directions: " . join(',',@directions));

    foreach my $next_direction ( $current_direction, @directions ) {
        my ( $test_x, $test_y ) = ( $next_x, $next_y );

        given ($next_direction) {
            when ('left') {
                $test_x--;
            }
            when ('right') {
                $test_x++;
            }
            when ('top') {
                $test_y++;
            }
            when ('bottom') {
                $test_y++;
            }
        }

        #$self->context->logger->debug("Trying direction: $next_direction, x: $test_x, y: $test_y");

        unless ( $test_x <= 0 || $test_y <= 0 || $sectors_created->[$test_x][$test_y] ) {
            return ( $next_direction, $test_x, $test_y );
        }
    }

    return;
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

            if ( $self->_has_available_path( $dest_x, $dest_y, $test_x, $test_y, $top_x, $top_y, $bottom_x, $bottom_y, $coords_available, $checked ) )
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

    $c->logger->debug( scalar @all_sectors . " sectors currently exist" );

    my $wall_to_join;
    SECTOR: foreach my $sector ( shuffle @all_sectors ) {
        if ( my @walls = $sector->walls ) {
            $c->logger->debug( "Sector: " . $sector->x . ", " . $sector->y . " has walls, checking if one can be joined on" );
            foreach my $wall ( shuffle @walls ) {
                my ( $opp_x, $opp_y ) = $wall->opposite_sector;

                #$c->logger->debug("Checking position: " . $wall->position->position);
                #$c->logger->debug("Opposite of wall is: $opp_x, $opp_y");

                next if $opp_x < 1 || $opp_y < 1;

                unless ( $sectors_created->[$opp_x][$opp_y] ) {

                    #$c->logger->debug("No sector exists opposite wall");

                    # Check there's no existing door
                    unless ( $sector->has_door( $wall->position->position ) ) {

                        #$c->logger->debug("No door exists opposite wall");

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

sub check_for_dungeon_deletion {
    my $self = shift;

    my $c = $self->context;

    my @dungeons = $c->schema->resultset('Dungeon')->search( {}, { prefetch => 'location', }, );

    foreach my $dungeon (@dungeons) {
        if ( Games::Dice::Advanced->roll('1d200') <= 1 ) {

            # Make sure no parties are in the dungeon
            my $party_rs =
                $c->schema->resultset('Party')
                ->search( { 'dungeon.dungeon_id' => $dungeon->id, }, { join => { 'dungeon_location' => { 'dungeon_room' => 'dungeon' } }, }, );

            if ( $party_rs->count > 0 ) {
                $c->logger->info(
                    'Note deleting dungeon at: ' . $dungeon->location->x . ", " . $dungeon->location->y . " as it has 1 or more parties inside" );
                next;
            }

            $c->logger->info( 'Deleting dungeon at: ' . $dungeon->location->x . ", " . $dungeon->location->y );

            # Delete the dungeon
            $dungeon->delete;
        }
    }
}

sub reconfigure_doors {
    my $self = shift;

    my $c = $self->context;

    my @doors = $c->schema->resultset('Door')->search( {} );

    my $processed_doors;

    foreach my $door (@doors) {
        unless ( $processed_doors->[ $door->id ] ) {
            my $opp_door = $door->opposite_door;

            my $door_type;
            if ( Games::Dice::Advanced->roll('1d100') <= 15 ) {
                $door_type = ( shuffle(@alternative_door_types) )[0];
            }
            else {
                $door_type = 'standard';
            }
            $door->type($door_type);
            $door->update;

            if ($opp_door) {
                $opp_door->type($door_type);
                $opp_door->update;
            }

            $processed_doors->[ $door->id ] = 1;
            $processed_doors->[ $opp_door->id ] = 1 if $opp_door;
        }

    }
}

my @TRAPS = qw/Curse Hypnotise Detonate/;

sub generate_treasure_chests {
	my $self = shift;
	my $dungeon = shift;
	
	my @rooms = $dungeon->rooms;    
	
	foreach my $room (@rooms) {
		my $chest_roll = Games::Dice::Advanced->roll('1d100');
		if ($chest_roll <= 20) {
			# Create a chest in this room
			my @sectors = $room->sectors;
			
			# Choose a sector
			my $sector_to_use;
			foreach my $sector (shuffle @sectors) {
				unless ($sector->has_door) {
					$sector_to_use = $sector;
					last;
				}
			}
			
			# Couldn't find a sector to use... skip this room
			next unless $sector_to_use;
			
			my $chest = $self->context->schema->resultset('Treasure_Chest')->create(
				{
					dungeon_grid_id => $sector_to_use->id,
				}
			);
			
			$self->fill_chest($chest);
		}
	}
}

my %item_types_by_prevalence;
sub fill_chest {
	my $self = shift;
	my $chest = shift;
	
	my $dungeon = $chest->dungeon_grid->dungeon_room->dungeon;
	
	unless (%item_types_by_prevalence) {
		my @item_types = $self->context->schema->resultset('Item_Type')->search(
	        {
	            'category.hidden'           => 0,
	        },
	        {
	            prefetch => { 'item_variable_params' => 'item_variable_name' },
	            join     => 'category',
	        },
	    );
	
	    map { push @{ $item_types_by_prevalence{ $_->prevalence } }, $_ } @item_types;
	}
	
	my $number_of_items = RPG::Maths->weighted_random_number(1..5);
				
	for (1..$number_of_items) {
		my $max_prevalence = Games::Dice::Advanced->roll('1d100') + (15 * $dungeon->level);
		$max_prevalence = 100 if $max_prevalence > 100;		

        my $item_type;
        while ( !defined $item_type ) {
            last if $max_prevalence > 100;
        	
    	    my @items = map { $_ <= $max_prevalence ? @{$item_types_by_prevalence{$_}} : () } keys %item_types_by_prevalence;
			$item_type = $items[ Games::Dice::Advanced->roll( '1d' . scalar @items ) - 1 ];
			
			$max_prevalence++;
		}
                
	    # We couldn't find a suitable item. Try again
	    next unless $item_type;
	            
		my $item = $self->context->schema->resultset('Items')->create(
			{
				item_type_id      => $item_type->id,
			    treasure_chest_id => $chest->id,
			}
	    );
	}
	
	# Add a trap
	if (Games::Dice::Advanced->roll('1d100') <= 20) {
		my $trap = (shuffle @TRAPS)[0];
		$chest->trap($trap);
		$chest->update;
	}
	else {
		$chest->trap(undef);
		$chest->update;
	}
	
}

sub fill_empty_chests {
	my $self = shift;
	
	my @chests = $self->context->schema->resultset('Treasure_Chest')->all;
	
	foreach my $chest (@chests) {
		unless ($chest->items) {
			if (Games::Dice::Advanced->roll('1d100') <= 50) {
				$self->fill_chest($chest);
			} 	
		}	
	}	
}

sub populate_sector_paths {
    my $self      = shift;
    my $dungeon   = shift;

	# TODO: we only calculate paths up to 3 moves. This may need to change if we allow parties to move further in one go
    my $max_moves = shift || 3;
    
    $self->context->logger->info("Populating sector paths for dungeon"); 
    
    my @sectors = $self->context->schema->resultset('Dungeon_Grid')->search(
        {
            'dungeon_room.dungeon_id' => $dungeon->id,
        },
        {
        	join => 'dungeon_room',
            prefetch => [ 
            	{ 'doors' => 'position' },
            	{ 'walls' => 'position' },
            ],
        },
    );    
    
    $self->context->logger->debug("Finding paths for " . scalar @sectors . " sectors");
    
    my $sectors_by_coord;
    foreach my $sector (@sectors) {
    	$sectors_by_coord->[$sector->x][$sector->y] = $sector;	
    }
    
    my $count = 0;
    
    foreach my $sector (@sectors) {    		
   		my ($top_left, $bottom_right) = RPG::Map->surrounds_by_range($sector->x, $sector->y, $max_moves);
    		
   		# Build a sector grid of all the sectors within the max_move range
   		my $sector_grid;
   		my @sectors_to_check;
   		for my $grid_x ($top_left->{x} .. $bottom_right->{x}) {
   			for my $grid_y ($top_left->{y} .. $bottom_right->{y}) {
   				my $check_sector = $sectors_by_coord->[$grid_x][$grid_y];
   				
   				next unless $check_sector;
   				
   				$sector_grid->[$grid_x][$grid_y] = $check_sector;
   				push @sectors_to_check, $check_sector;
   			}	
   		}	
    		
   		# Check all the sectors in range to see if they have a path
   		foreach my $sector_to_check (@sectors_to_check) {
   			#warn "Top level, find path for: " . $sector->x . ", " . $sector->y . " -> " . $sector_to_check->x . ", " . $sector_to_check->y . "\n";
   			
   			my $result = $self->check_has_path($sector, $sector_to_check, $sector_grid, $max_moves);
   			
   			#warn "Got result, has_path: " . $result->{has_path} . ", doors_in_path: " . 
   			#	(ref $result->{doors_in_path} eq 'ARRAY' ? scalar @{ $result->{doors_in_path} } : 'none' ) . "\n";  
   			
   			if ($result->{has_path}) {
   				# This one has a path, write it to the DB
   				$count++;
 				
 				#warn $result->{moves_made};
   				$self->context->schema->resultset('Dungeon_Sector_Path')->create(
					{
						sector_id => $sector->id,
						has_path_to => $sector_to_check->id,
						distance => $result->{moves_made},
					}
				);

				
				foreach my $door_in_path (@{$result->{doors_in_path}}) {
					#warn ref $door_in_path;
					$self->context->schema->resultset('Dungeon_Sector_Path_Door')->find_or_create(
						{
							sector_id => $sector->id,
							has_path_to => $sector_to_check->id,
							door_id => $door_in_path->id,	
						}
					);
				}
   			}
   		}
    }
    
    $self->context->logger->info("Finished populating paths, found $count paths");
}

sub check_has_path {
    my $self          = shift;
    my $start_sector  = shift;    
    my $target_sector = shift;
    my $sector_grid   = shift;
    my $max_moves     = shift;
    my $moves_made    = shift;
    my $sectors_tried = shift;

    $moves_made = 0 unless defined $moves_made;

    $moves_made++;

    return {has_path=>0} if $moves_made > $max_moves;

    my ( $x, $y ) = ( $target_sector->x, $target_sector->y );

    $sectors_tried->[$x][$y] = 1;

	#warn "Start sector: " . $start_sector->x . ", " . $start_sector->y;
    #warn "Trying sector: $x, $y\n";

	my @paths_to_check = $self->compute_paths_to_check($start_sector, $target_sector);

    my $move_cache;
    
    my @paths_found;

    foreach my $path (@paths_to_check) {
        my ( $test_x, $test_y ) = @$path;

    	my @doors_in_path;

        #warn "Testing: $x, $y -> $test_x, $test_y (current moves: $moves_made)\n";

        if ( !$sectors_tried->[$test_x][$test_y] && $sector_grid->[$test_x][$test_y] ) {

            my $sector_to_try = $sector_grid->[$test_x][$test_y];

            #warn "Seeing if we can move there...\n";
            
            my $cache_key = $target_sector->x . '-' . $target_sector->y . '-' . $sector_to_try->x . '-' . $sector_to_try->y;
            
            my $has_path;
            my $result = $move_cache->{$cache_key} // $self->can_move_to($target_sector, $sector_to_try);
           	$has_path = $result->{has_path};
            
            $move_cache->{$cache_key} = $result;

            unless ($has_path) {
            	#warn "Can't find a path path\n";
            	next;	
            }
            
            push @doors_in_path, @{$result->{doors_in_path}} if @{$result->{doors_in_path}};
            
            #warn "Doors_in_path: " . scalar @doors_in_path;

            #warn "(we can)\n";

            if ( $start_sector->x == $test_x && $start_sector->y == $test_y ) {
                #warn ".. dest is reached";
                # Dest reached
                push @paths_found, {
                	has_path => 1,
                	doors_in_path => \@doors_in_path,	
                	moves_made => $moves_made,
                };
                next;
            }

			# Still not at dest, recurse to find another path
			my $recursed_result = $self->check_has_path( $start_sector, $sector_to_try, $sector_grid, $max_moves, $moves_made, clone $sectors_tried );
            if ( $recursed_result->{has_path} ) {
                #warn "... path found";
                push @doors_in_path, @{$recursed_result->{doors_in_path}} if @{$recursed_result->{doors_in_path}}; 
                push @paths_found, {
                	has_path => 1,
                	doors_in_path => \@doors_in_path,
                	moves_made => $recursed_result->{moves_made},
                };
            }
            
            #warn ".. no path found";
        }

    }
    
    if (@paths_found) {
    	# Find the best path
    	my $best_path = shift @paths_found; # Start with a random path
    	foreach my $path_found (@paths_found) {
    		if ($path_found->{moves_made} < $best_path->{moves_made}) {
    			$best_path = $path_found;
    			next;	
    		}
    		
    		# We prefer paths with less doors, since they could be unpassable
    		if ($path_found->{moves_made} == $best_path->{moves_made} 
    			&& scalar @{$path_found->{doors_in_path}} < scalar @{$best_path->{doors_in_path}} ) {
    			$best_path = $path_found;
    			next;
    		}
    	}
    	
    	return $best_path;
    }
    else {
	    return {has_path => 0};
    }
}

sub compute_paths_to_check {
	my $self = shift;
	my $start_sector = shift;
	my $target_sector = shift;
	
	my ($x, $y) = ($target_sector->x, $target_sector->y);
	
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
    
	my $adjacent = RPG::Map->is_adjacent_to(
        {
            x => $start_sector->x,
            y => $start_sector->y,
        },
        {
            x => $target_sector->x,
            y => $target_sector->y,
        },
    );    
    
    # If sectors are adjacent, check direct path first
    if ($adjacent) {
    	@paths_to_check = grep { ! ($->[0] == $start_sector->x && $_->[1] == $start_sector->y) } @paths_to_check; 
    	unshift @paths_to_check, [ $start_sector->x , $start_sector->y]	
    }
    
    return @paths_to_check;
		
}

sub can_move_to {
    my $self   = shift;
    my $start  = shift;
    my $sector = shift;

    #warn "in _can_move_to\n";
    #warn "src: " . $self->x . ", " . $self->y;
    #warn "dest: " . $sector->x . ", " . $sector->y;

    # Can't move to sector if src/dest are the same
    return {has_path=>0} if $start->x == $sector->x && $start->y == $sector->y;

    #warn "checking is adjacent to\n";

    # Sectors must be adjacent
    return {has_path=>0} unless RPG::Map->is_adjacent_to(
        {
            x => $start->x,
            y => $start->y,
        },
        {
            x => $sector->x,
            y => $sector->y,
        },
    );
    
    #warn "checking for non diagonal sectors\n";

    # Now, check walls/doors on sectors on non diagonal

    # Sector to the right
    if ( $start->x < $sector->x && $start->y == $sector->y ) {
		return $self->get_non_diag_result($start, 'right');
    }

    # Sector to the left    
    if ( $start->x > $sector->x && $start->y == $sector->y ) {
    	return $self->get_non_diag_result($start, 'left');
    }

    # Sector above
    if ( $start->y > $sector->y && $start->x == $sector->x ) {
		return $self->get_non_diag_result($start, 'top');
    }

    # Sector below
    if ( $start->y < $sector->y && $start->x == $sector->x ) {
		return $self->get_non_diag_result($start, 'bottom');
    }

    # See if the sector is on the diagonal
    my $diagonal_to_check;
    if ( $start->x > $sector->x && $start->y > $sector->y ) {
        $diagonal_to_check = 'top_left';
    }
    elsif ( $start->x < $sector->x && $start->y > $sector->y ) {
        $diagonal_to_check = 'top_right';
    }
    elsif ( $start->x > $sector->x && $start->y < $sector->y ) {
        $diagonal_to_check = 'bottom_left';
    }
    elsif ( $start->x < $sector->x && $start->y < $sector->y ) {
        $diagonal_to_check = 'bottom_right';
    }
    
    #warn "must be diagonal sector: $diagonal_to_check\n";

    # Should never happen... (!)
    croak "Couldn't find position of adjacent sector (src: " . $start->x . ", " . $start->y . "; dest: " . $sector->x . ", " . $sector->y . ")"
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

    my $dest_pos1_blocked = $sector->has_wall($dest_wall_1) && ( $start->has_wall($src_wall_2) || !$sector->has_door($dest_wall_1) );
    my $dest_pos2_blocked = $sector->has_wall($dest_wall_2) && ( $start->has_wall($src_wall_1) || !$sector->has_door($dest_wall_1));
    
    if ($dest_pos1_blocked && $dest_pos2_blocked) {
    	return {
    		has_path => 0,
    	}
    }

    my $src_pos1_blocked = $start->has_wall($src_wall_1) && ( $sector->has_wall($dest_wall_2) || !$start->has_door($src_wall_1) );
    my $src_pos2_blocked = $start->has_wall($src_wall_2) && ( $sector->has_wall($dest_wall_1) || !$start->has_door($src_wall_2) );
    
    if ($src_pos1_blocked && $src_pos2_blocked) {
    	return {
    		has_path => 0,
    	}
    }    
    
    # Now check if there's a horizontal or vertical blockage
    return {has_path => 0} if ($start->has_wall($src_wall_1) && ! $start->has_door($src_wall_1)) && ($sector->has_wall($dest_wall_1) && ! $sector->has_door($dest_wall_1));
    return {has_path => 0} if ($start->has_wall($src_wall_2) && ! $start->has_door($src_wall_2)) && ($sector->has_wall($dest_wall_2) && ! $sector->has_door($dest_wall_2)); 
    
    #warn "No blockages found\n";
    
    # Only get here if move can be completed
    
    # Assemble array of doors in this path
    
    my @doors_in_path;
    push @doors_in_path, $start->get_door_at($src_wall_1) // ();
    push @doors_in_path, $start->get_door_at($src_wall_2) // ();
    push @doors_in_path, $sector->get_door_at($dest_wall_1) // ();
    push @doors_in_path, $sector->get_door_at($dest_wall_2) // ();
   
    return {
    	has_path => 1,
    	doors_in_path => \@doors_in_path,
    };
}

sub get_non_diag_result {
	my $self = shift;
	my $sector = shift;
	my $direction = shift;
	
    if ( $sector->has_wall($direction) && !$sector->has_door($direction) ) {
        return {has_path => 0};
    }
    else {
        return {
			has_path => 1,
			doors_in_path => [$sector->get_door_at($direction) // ()],            	
        };
    }	
}

1;
