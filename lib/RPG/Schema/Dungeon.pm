use strict;
use warnings;

package RPG::Schema::Dungeon;

use base 'DBIx::Class';

use Carp;
use Data::Dumper;
use Clone qw(clone);

use RPG::Map;
use RPG::Position;
use AI::Pathfinding::AStar::Rectangle;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Dungeon');

__PACKAGE__->add_columns(qw/dungeon_id level land_id name type/);

__PACKAGE__->set_primary_key('dungeon_id');

__PACKAGE__->has_many( 'rooms', 'RPG::Schema::Dungeon_Room', { 'foreign.dungeon_id' => 'self.dungeon_id' } );

__PACKAGE__->belongs_to( 'location', 'RPG::Schema::Land', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->might_have( 'town', 'RPG::Schema::Town', { 'foreign.land_id' => 'self.land_id' } );

sub delete {
    my ( $self, @args ) = @_;

	# Check for any quests relating to this dungeon, and delete them
	my @quests = $self->result_source->schema->resultset('Quest')->search(
		{
			'type.quest_type' => 'find_dungeon_item',
			'quest_param_name.quest_param_name' => 'Dungeon',
			'start_value' => $self->id,
		},
		{
			join => ['type', {'quest_params' => 'quest_param_name'}],
		}
	);
	
	map { $_->delete } @quests;
	
    my $ret = $self->next::method(@args);

    return $ret;
}

sub party_can_enter {
	my $self = shift;

	my $level;
	if ( ref $self && $self->isa('RPG::Schema::Dungeon') ) {
		$level = $self->level;
	}
	else {

		# Called as a class method
		$level = shift;
	}

	croak "Level not supplied" unless $level;

	my $party = shift || croak "Party not supplied";

	return ( $level - 1 ) * RPG::Schema->config->{dungeon_entrance_level_step} <= $party->level ? 1 : 0;
}

sub treasure_chests {
	my $self = shift;
	
	return $self->result_source->schema->resultset('Treasure_Chest')->search(
		{
			'dungeon_room.dungeon_id' => $self->id,
		},
		{
			join => {'dungeon_grid' => 'dungeon_room'},
		}
	);
}

sub find_path_to_sector {
	my $self         = shift;
	my $start_sector = shift;
	my $end          = shift;

	my $start = {
		x => $start_sector->x,
		y => $start_sector->y,
	};

	my $distance = RPG::Map->get_distance_between_points(
		$start,
		$end,
	);
		
	my ( $top_left, $bottom_right ) = RPG::Map->surrounds_by_range(
		$start->{x},
		$start->{y},
		$distance,
	);

	# TODO: cache this?
	my @sectors = $self->result_source->schema->resultset('Dungeon_Grid')->search(
		{
			'x'                                => { '>=', $top_left->{x}, '<=', $bottom_right->{x}, },
			'y'                                => { '>=', $top_left->{y}, '<=', $bottom_right->{y}, },
			'dungeon_room.dungeon_id'          => $self->id,
			'dungeon_room.floor'               => $start_sector->dungeon_room->floor,
			'creature_group.creature_group_id' => undef,
		},
		{
			join => [ 'dungeon_room', 'creature_group' ],
		}
	);

	my $sectors_allowed_to_move_to = $start_sector->sectors_allowed_to_move_to(3);
	
	my $map = AI::Pathfinding::AStar::Rectangle->new( { height => $bottom_right->{y} + 1, width => $bottom_right->{x} + 1 } );
	$map->set_passability( $start_sector->x, $start_sector->y, 1 );

	foreach my $sector (@sectors) {

		# If it's within 3 sectors of the start sector, it's passable if it's in $sectors_allowed_to_move_to
		#  Otherwise it's passable if it exists.
		# That's actually wrong.. but paths are only calculated up to 3 moves, and the thing calling this
		#  will (hopefully) only use the first 3 moves, and can then recalculate from it's new location.
		my $distance_to_start = RPG::Map->get_distance_between_points(
			$start,
			{
				x => $sector->x,
				y => $sector->y,
			}
		);

		my $passable = 0;
		if ( $distance_to_start <= 3 && $distance_to_start > 0 ) {
			$passable = 1 if $sectors_allowed_to_move_to->{ $sector->id };
		}
		else {
			$passable = 1;
		}
		#warn $sector->x . ", " . $sector->y . ": $passable";
		$map->set_passability( $sector->x, $sector->y, $passable );
	}

	my $path = $map->astar( $start->{x}, $start->{y}, $end->{x}, $end->{y} );

	my @path;
	my $last_coord = $start;
	foreach my $direction ( split //, $path ) {
		my $next_coord = RPG::Map->adjust_coord_by_direction( $last_coord, $direction );
		push @path, $next_coord;
		$last_coord = clone $next_coord;
	}
	
	@path = ($start) unless @path;

	return @path;

}

sub populate_sector_paths {
	my $self    = shift;

	# TODO: we only calculate paths up to 3 moves. This may need to change if we allow parties to move further in one go
	my $max_moves = shift || 3;

	my $floors = $self->result_source->schema->resultset('Dungeon_Room')->find(
		{
			'dungeon_id' => $self->id,
		},
		{ select => [
			{ max => 'floor' },
		  ],
		  as => ['floor_count'],		  	
		},
	)->get_column('floor_count');
		
	for my $floor (1..$floors) {
		my @sectors = $self->result_source->schema->resultset('Dungeon_Grid')->search(
			{
				'dungeon_room.dungeon_id' => $self->id,
				'dungeon_room.floor' => $floor,
			},
			{
				join     => 'dungeon_room',
				prefetch => [
					{ 'doors' => 'position' },
					{ 'walls' => 'position' },
				],
			},
		);
		
		my $sectors_by_coord;
		foreach my $sector (@sectors) {
			$sectors_by_coord->[ $sector->x ][ $sector->y ] = $sector;
		}
	
		my $count = 0;
	
		foreach my $sector (@sectors) {
			my ( $top_left, $bottom_right ) = RPG::Map->surrounds_by_range( $sector->x, $sector->y, $max_moves );
	
			# Build a sector grid of all the sectors within the max_move range
			my $sector_grid;
			my @sectors_to_check;
			for my $grid_x ( $top_left->{x} .. $bottom_right->{x} ) {
				for my $grid_y ( $top_left->{y} .. $bottom_right->{y} ) {
					my $check_sector = $sectors_by_coord->[$grid_x][$grid_y];
	
					next unless $check_sector;
	
					$sector_grid->[$grid_x][$grid_y] = $check_sector;
					push @sectors_to_check, $check_sector;
				}
			}
	
			# Check all the sectors in range to see if they have a path
			foreach my $sector_to_check (@sectors_to_check) {
	
				#warn "Top level, find path for: " . $sector->x . ", " . $sector->y . " -> " . $sector_to_check->x . ", " . $sector_to_check->y . "\n";
	
				my $result = $self->check_has_path( $sector, $sector_to_check, $sector_grid, $max_moves );
	
				#warn "Got result, has_path: " . $result->{has_path} . ", doors_in_path: " .
				#	(ref $result->{doors_in_path} eq 'ARRAY' ? scalar @{ $result->{doors_in_path} } : 'none' ) . "\n";
	
				if ( $result->{has_path} ) {
	
					# This one has a path, write it to the DB
					$count++;
	
					#warn $result->{moves_made};
					$self->result_source->schema->resultset('Dungeon_Sector_Path')->create(
						{
							sector_id   => $sector->id,
							has_path_to => $sector_to_check->id,
							distance    => $result->{moves_made},
						}
					);
	
					foreach my $door_in_path ( @{ $result->{doors_in_path} } ) {
	
						#warn ref $door_in_path;
						$self->result_source->schema->resultset('Dungeon_Sector_Path_Door')->find_or_create(
							{
								sector_id   => $sector->id,
								has_path_to => $sector_to_check->id,
								door_id     => $door_in_path->id,
							}
						);
					}
				}
			}
		}
	}
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

	return { has_path => 0 } if $moves_made > $max_moves;

	my ( $x, $y ) = ( $target_sector->x, $target_sector->y );

	$sectors_tried->[$x][$y] = 1;

	#warn "Start sector: " . $start_sector->x . ", " . $start_sector->y;
	#warn "Trying sector: $x, $y\n";

	my @paths_to_check = $self->compute_paths_to_check( $start_sector, $target_sector );

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
			my $result = $move_cache->{$cache_key} // $self->can_move_to( $target_sector, $sector_to_try );
			$has_path = $result->{has_path};

			$move_cache->{$cache_key} = $result;

			unless ($has_path) {

				#warn "Can't find a path path\n";
				next;
			}

			push @doors_in_path, @{ $result->{doors_in_path} } if @{ $result->{doors_in_path} };

			#warn "Doors_in_path: " . scalar @doors_in_path;

			#warn "(we can)\n";

			if ( $start_sector->x == $test_x && $start_sector->y == $test_y ) {

				#warn ".. dest is reached";
				# Dest reached
				push @paths_found,
					{
					has_path      => 1,
					doors_in_path => \@doors_in_path,
					moves_made    => $moves_made,
					};
				next;
			}

			# Still not at dest, recurse to find another path
			my $recursed_result = $self->check_has_path( $start_sector, $sector_to_try, $sector_grid, $max_moves, $moves_made, clone $sectors_tried );
			if ( $recursed_result->{has_path} ) {

				#warn "... path found";
				push @doors_in_path, @{ $recursed_result->{doors_in_path} } if @{ $recursed_result->{doors_in_path} };
				push @paths_found,
					{
					has_path      => 1,
					doors_in_path => \@doors_in_path,
					moves_made    => $recursed_result->{moves_made},
					};
			}

			#warn ".. no path found";
		}

	}

	if (@paths_found) {

		# Find the best path
		my $best_path = shift @paths_found;    # Start with a random path
		foreach my $path_found (@paths_found) {
			if ( $path_found->{moves_made} < $best_path->{moves_made} ) {
				$best_path = $path_found;
				next;
			}

			# We prefer paths with less doors, since they could be unpassable
			if ( $path_found->{moves_made} == $best_path->{moves_made}
				&& scalar @{ $path_found->{doors_in_path} } < scalar @{ $best_path->{doors_in_path} } )
			{
				$best_path = $path_found;
				next;
			}
		}

		return $best_path;
	}
	else {
		return { has_path => 0 };
	}
}

sub compute_paths_to_check {
	my $self          = shift;
	my $start_sector  = shift;
	my $target_sector = shift;

	my ( $x, $y ) = ( $target_sector->x, $target_sector->y );

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
		@paths_to_check = grep { !( $- > [0] == $start_sector->x && $_->[1] == $start_sector->y ) } @paths_to_check;
		unshift @paths_to_check, [ $start_sector->x, $start_sector->y ];
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
	return { has_path => 0 } if $start->x == $sector->x && $start->y == $sector->y;

	#warn "checking is adjacent to\n";

	# Sectors must be adjacent
	return { has_path => 0 } unless RPG::Map->is_adjacent_to(
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
		return $self->get_non_diag_result( $start, 'right' );
	}

	# Sector to the left
	if ( $start->x > $sector->x && $start->y == $sector->y ) {
		return $self->get_non_diag_result( $start, 'left' );
	}

	# Sector above
	if ( $start->y > $sector->y && $start->x == $sector->x ) {
		return $self->get_non_diag_result( $start, 'top' );
	}

	# Sector below
	if ( $start->y < $sector->y && $start->x == $sector->x ) {
		return $self->get_non_diag_result( $start, 'bottom' );
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
	my $dest_pos2_blocked = $sector->has_wall($dest_wall_2) && ( $start->has_wall($src_wall_1) || !$sector->has_door($dest_wall_1) );

	if ( $dest_pos1_blocked && $dest_pos2_blocked ) {
		return {
			has_path => 0,
		};
	}

	my $src_pos1_blocked = $start->has_wall($src_wall_1) && ( $sector->has_wall($dest_wall_2) || !$start->has_door($src_wall_1) );
	my $src_pos2_blocked = $start->has_wall($src_wall_2) && ( $sector->has_wall($dest_wall_1) || !$start->has_door($src_wall_2) );

	if ( $src_pos1_blocked && $src_pos2_blocked ) {
		return {
			has_path => 0,
		};
	}

	# Now check if there's a horizontal or vertical blockage
	return { has_path => 0 }
		if ( $start->has_wall($src_wall_1) && !$start->has_door($src_wall_1) )
		&& ( $sector->has_wall($dest_wall_1) && !$sector->has_door($dest_wall_1) );
	return { has_path => 0 }
		if ( $start->has_wall($src_wall_2) && !$start->has_door($src_wall_2) )
		&& ( $sector->has_wall($dest_wall_2) && !$sector->has_door($dest_wall_2) );

	#warn "No blockages found\n";

	# Only get here if move can be completed

	# Assemble array of doors in this path

	my @doors_in_path;
	push @doors_in_path, $start->get_door_at($src_wall_1)   // ();
	push @doors_in_path, $start->get_door_at($src_wall_2)   // ();
	push @doors_in_path, $sector->get_door_at($dest_wall_1) // ();
	push @doors_in_path, $sector->get_door_at($dest_wall_2) // ();

	return {
		has_path      => 1,
		doors_in_path => \@doors_in_path,
	};
}

sub get_non_diag_result {
	my $self      = shift;
	my $sector    = shift;
	my $direction = shift;

	if ( $sector->has_wall($direction) && !$sector->has_door($direction) ) {
		return { has_path => 0 };
	}
	else {
		return {
			has_path      => 1,
			doors_in_path => [ $sector->get_door_at($direction) // () ],
		};
	}
}

1;
