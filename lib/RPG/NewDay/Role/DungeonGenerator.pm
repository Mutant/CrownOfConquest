package RPG::NewDay::Role::DungeonGenerator;

use Moose::Role;
use warnings;
use Carp;
use feature 'switch';

use List::Util qw(shuffle);
use Clone qw(clone);

has 'positions' => ( is => 'ro', isa => 'HashRef', init_arg => undef, builder => '_build_positions', lazy => 1, );

sub alternative_door_types {
	my @alternative_door_types = qw/stuck locked sealed secret/;

	return @alternative_door_types;
}

sub _build_positions {
	my $self = shift;

	return { map { $_->position => $_->position_id } $self->context->schema->resultset('Dungeon_Position')->search };
}

sub get_door_type {
	my $self = shift;
	
	my $door_type = 'standard';
	
	if ( Games::Dice::Advanced->roll('1d100') <= 15 ) {
		$door_type = ( shuffle( $self->alternative_door_types ) )[0];
	}
	
	return $door_type;
}

sub generate_dungeon_grid {
	my $self      = shift;
	my $dungeon   = shift;
	my $number_of_rooms = shift;
	my $corridor_chance = shift // 15;

	# Number of rooms is an array ref, with each element the number of rooms on that floor
	if (! ref $number_of_rooms) {
		$number_of_rooms = [$number_of_rooms];	
	}
	
	my $positions = $self->positions;

	my $c = $self->context;

	my $floor = 0;
	foreach my $room_count (@$number_of_rooms) {
		$floor++; 
		$c->logger->debug("Creating $room_count rooms in floor $floor of dungeon");

		my $sectors_created;
	
		for my $current_room_number ( 1 .. $room_count ) {

			$c->logger->debug("Creating room # $current_room_number");
	
			my ( $start_x, $start_y );
	
			my $wall_to_join;
			my $door_type;
	
			if ( $current_room_number == 1 ) {
	
				# Pick a spot for the first room
				$start_x = 35;
				$start_y = 35;
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
				$door_type = $self->get_door_type;
	
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
			if ( $corridor_roll <= $corridor_chance ) {
				@new_sectors = $self->_create_corridor( $dungeon, $start_x, $start_y, $floor, $sectors_created, $positions );
			}
			else {
				@new_sectors = $self->_create_room( $dungeon, $start_x, $start_y, $floor, $sectors_created, $positions );
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
		
		my @all_sectors;
		foreach my $y_line (@$sectors_created) {
			foreach my $sector (@$y_line) {
				next unless defined $sector;
				push @all_sectors, $sector;
			}
		}	
		
		my $extra_doors = Games::Dice::Advanced->roll('1d6') + int $room_count / 10 + 3;
		$c->logger->debug("Generating $extra_doors extra doors");
		for (1 .. $extra_doors) {
			$self->_generate_extra_doors(\@all_sectors);
		}
		
		# If there's a floor below this one, create the stairs down
		if ($number_of_rooms->[$floor]) {
			foreach my $sector (shuffle @all_sectors) {
				# Want a sector without stairs and doors
				next if $sector->stairs_up;
				next if $sector->sides_with_doors;
				
				# TODO: also no teleporter or chest
				
				$sector->stairs_down(1);
				$sector->update;
				
				last;
			}
		}		
	}
}

sub _create_room {
	my $self            = shift;
	my $dungeon         = shift;
	my $start_x         = shift;
	my $start_y         = shift;
	my $floor           = shift;
	my $sectors_created = shift;
	my $positions       = shift;

	my $c = $self->context;

	my ( $top_x, $top_y, $x_size, $y_size ) = $self->_find_room_dimensions( $start_x, $start_y );
	my $bottom_x = $top_x + $x_size - 1;
	my $bottom_y = $top_y + $y_size - 1;

	#warn "$top_x, $top_y, $bottom_x, $bottom_y\n";
	#warn Dumper $sectors_created;

	my $room = $c->schema->resultset('Dungeon_Room')->create( { dungeon_id => $dungeon->id, floor => $floor, } );

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
	my $floor           = shift;
	my $sectors_created = shift;
	my $positions       = shift;

	my $c = $self->context;

	my $room = $c->schema->resultset('Dungeon_Room')->create( { dungeon_id => $dungeon->id,	floor => $floor,} );

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

sub populate_sector_paths {
	my $self = shift;
	my $dungeon = shift;
	my $max_moves = shift;
	
	$dungeon->populate_sector_paths($max_moves);
		
}

# Find random sectors joining two rooms (i.e. with walls between them) that don't already have doors, 
#  and create a new door there. This creates dungeons with multiple paths between rooms
sub _generate_extra_doors {
	my $self = shift;
	my $sectors = shift;
	
	SECTOR: foreach my $sector (shuffle @$sectors) {
		# Find the walls for this sector, if any
		my @walls = $sector->walls;
		next unless @walls;
		
		# We have some walls, find one that doesn't already have a door, if any
		foreach my $wall (shuffle @walls) {
			my $pos = $wall->position->position;
			
			next if $sector->has_door($pos);
			
			# Now see if there's already a door in this room in the same
			#  position, on the same x/y access (depending on position).
			#  This avoids two doors opening into the same room in the same
			#  direction (which is pretty much pointless)
			
			my $axis;
			$axis = 'y';
			$axis = 'x' if $pos eq 'right' or $pos eq 'left';
			
			my $other_doors = $self->context->schema->resultset('Door')->search(
				{
					"dungeon_grid.$axis" => $sector->$axis,
					'position.position' => $pos,
					'dungeon_grid.dungeon_room_id' => $sector->dungeon_room_id,
				},
				{
					join => ['dungeon_grid', 'position'],
				},
			)->count;
			
			next if $other_doors >= 1;
			
			# Looks good, now see if there's a sector on the other side of the wall
			my $opposite_wall = $wall->opposite_wall;
			
			next unless $opposite_wall;
			
			# Ok, we've got an opposite wall - we can create a door now.
			my $door_type = $self->get_door_type;
			
			my $door1 = $self->context->schema->resultset('Door')->create(
				{
					position_id     => $wall->position_id,
					dungeon_grid_id => $wall->dungeon_grid_id,
					type            => $door_type,
				}
			);

			my $door2 = $self->context->schema->resultset('Door')->create(
				{
					position_id     => $opposite_wall->position_id,
					dungeon_grid_id => $opposite_wall->dungeon_grid_id,
					type            => $door_type,
				}
			);
			
			last SECTOR;
		}
	}
}

1;
