package RPG::C::Dungeon;

use strict;
use warnings;
use base 'Catalyst::Controller';

use feature "switch";

use Data::Dumper;
use Carp;
use List::Util qw(shuffle);
use Statistics::Basic qw(average);
use JSON;

use RPG::Map;
use RPG::NewDay::Action::Dungeon;

sub view : Local {
    my ( $self, $c ) = @_;

    $c->stats->profile("Entered /dungeon/view");
    
    my $current_location = $c->model('DBIC::Dungeon_Grid')->find( 
    	{ dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, }, 
    	{ prefetch => {'dungeon_room' => 'dungeon'}, } 
	);
	
	$c->stash->{dungeon} = $current_location->dungeon_room->dungeon;
	$c->stash->{dungeon_type} = $c->stash->{dungeon}->type;

    $c->log->debug( "Current location: " . $current_location->x . ", " . $current_location->y );

    # Get all sectors that the party has mapped
    $c->log->debug("Getting mapped sectors");
    my @mapped_sectors = $c->model('DBIC::Dungeon_Grid')->get_party_grid( 
    	$c->stash->{party}->id, 
    	$current_location->dungeon_room->dungeon_id,
    	$current_location->dungeon_room->floor, 
    );

    $c->stats->profile("Queried map sectors");

	my $grids = $c->stash->{saved_grid} || $c->forward('build_viewable_sector_grids', [$current_location]);
	my ($sectors, $viewable_sector_grid, $allowed_to_move_to, $cgs, $parties) = @$grids;

    my $mapped_sectors_by_coord;
    foreach my $sector (@mapped_sectors) {
        $mapped_sectors_by_coord->[ $sector->{x} ][ $sector->{y} ] = $sector;
    }
	
	# Add any sectors from viewable grid into mapped sectors, if they're not there already
	$c->log->debug("Raw viewable sectors: " . scalar @$sectors);
	foreach my $sector (@$sectors) {
		if (! $mapped_sectors_by_coord->[ $sector->{x} ][ $sector->{y} ] && $viewable_sector_grid->[ $sector->{x} ][ $sector->{y} ]) {
			push @mapped_sectors, $sector;
		}	
	}

    $c->stats->profile("Finshed /dungeon/view");

    return $c->forward( 'render_dungeon_grid', [ $viewable_sector_grid, \@mapped_sectors, $allowed_to_move_to, $current_location, $cgs, $parties ] );
}

sub build_viewable_sector_grids : Private {
	my ($self, $c, $current_location) = @_;
	
	$c->stats->profile("in build_viewable_sector_grids");	
	
    # Find actual list of sectors party can move to
    my ( $top_corner, $bottom_corner ) = RPG::Map->surrounds_by_range( $current_location->x, $current_location->y, 3 );
    $c->log->debug("Getting sectors allowed to move to");
   
    my @sectors = $c->model('DBIC::Dungeon_Grid')->get_party_grid(
    	undef, # Don't supply party_id as we want sectors whether they're mapped by the party or not
    	$current_location->dungeon_room->dungeon_id,
    	$current_location->dungeon_room->floor,
    	{
    		top_corner => $top_corner,
    		bottom_corner => $bottom_corner,
    	},
    );
    
    $c->stats->profile("Queried sectors allowed to move to");

	my $allowed_to_move_to = $current_location->sectors_allowed_to_move_to( $c->config->{dungeon_move_maximum} );

    $c->stats->profile("Built allowed to move to hash");
	
    # Get cgs in viewable area
    my $cgs;
    my @cg_recs = $c->model('DBIC::Dungeon_Grid')->search(
        {
            x                              => { '>=', $top_corner->{x}, '<=', $bottom_corner->{x} },
            y                              => { '>=', $top_corner->{y}, '<=', $bottom_corner->{y} },
            'dungeon_room.dungeon_room_id' => $current_location->dungeon_room_id,
            'dungeon_room.floor'           => $current_location->dungeon_room->floor,
        },
        {
            prefetch => [ { 'creature_group' => { 'creatures' => 'type' } }, ],
            join     => 'dungeon_room',
        },
    );
    foreach my $cg_rec (@cg_recs) {
        my $cg = $cg_rec->creature_group;
        
        if ($cg) {
            my @creatures = sort { $a->id <=> $b->id } grep { ! $_->is_dead && $_->type->image ne 'defaultportsmall.png' } $cg->creatures;
            
            if (@creatures) {
                $cg->{portrait} = $creatures[0]->type->image;
            }
            else {
                $cg->{portrait} = 'defaultportsmall.png';
            }
        }
        
        $cgs->[ $cg_rec->x ][ $cg_rec->y ] = $cg;
    }
 
    $c->stats->profile("Got CGs");	

	# Get parties in viewbale area
    my $parties;
    my @party_recs = $c->model('DBIC::Dungeon_Grid')->search(
        {
            x                              => { '>=', $top_corner->{x}, '<=', $bottom_corner->{x} },
            y                              => { '>=', $top_corner->{y}, '<=', $bottom_corner->{y} },
            'dungeon_room.dungeon_room_id' => $current_location->dungeon_room_id,
            'dungeon_room.floor'           => $current_location->dungeon_room->floor,
            'parties.party_id'             => { '!=', $c->stash->{party}->id },
            'parties.defunct'              => undef,
        },
        {
            prefetch => [ { 'parties' => { 'characters' => 'class' } }, ],
            join     => 'dungeon_room',
        },
    );
    foreach my $party_rec (@party_recs) {
        my @parties = $party_rec->parties;
        if ($parties[0]) {
            my @characters = sort { $a->party_order <=> $b->party_order } grep { ! $_->is_dead } $parties[0]->members;
            $parties[0]->{portrait} = $characters[0]->portrait;
        }
        
        $parties->[ $party_rec->x ][ $party_rec->y ] = \@parties;
    }
 
    $c->stats->profile("Got Parties");	    
	
    # Find viewable sectors, add newly discovered sectors to party's map
    my @viewable_sectors;
    foreach my $sector (@sectors) {
        next unless $sector->{dungeon_room}{dungeon_room_id} == $current_location->dungeon_room_id;
        
	    # Make sure all the viewable sectors have a path back to the starting square (i.e. there's no breaks 
	    #  in the viewable area, avoids the problem of twisting corridors having two lighted sections)
	    # TODO: prevent light going round corners (?)
        next unless $current_location->id == $sector->{dungeon_grid_id} 
        	|| $current_location->has_path_to($sector->{dungeon_grid_id}, 3);

        push @viewable_sectors, $sector;

        # Save newly mapped sectors 
        my $mapped = $c->model('DBIC::Mapped_Dungeon_Grid')->find_or_create(
	        {
    	        party_id        => $c->stash->{party}->id,
                dungeon_grid_id => $sector->{dungeon_grid_id},
            }
        );
    }
    
    my $viewable_sectors_by_coord;
    foreach my $viewable_sector (@viewable_sectors) {
        $viewable_sectors_by_coord->[ $viewable_sector->{x} ][ $viewable_sector->{y} ] = 1;
    }    
    
    $c->stats->profile("Got viewable sectors");	

    return [\@sectors, $viewable_sectors_by_coord, $allowed_to_move_to, $cgs, $parties];		
}

sub render_dungeon_grid : Private {
    my ( $self, $c, $viewable_sectors, $mapped_sectors, $allowed_to_move_to, $current_location, $cgs, $parties ) = @_;

    my @positions = map { $_->position } $c->model('DBIC::Dungeon_Position')->search;

    my $grid;
    my ( $min_x, $min_y, $max_x, $max_y ) = ( $mapped_sectors->[0]->{x}, $mapped_sectors->[0]->{y}, 0, 0 );

    foreach my $sector (@$mapped_sectors) {

        $c->log->debug( "Rendering dungeon sector: " . $sector->{x} . ", " . $sector->{y} );
        $grid->[ $sector->{x} ][ $sector->{y} ] = $sector;

        $max_x = $sector->{x} if $max_x < $sector->{x};
        $max_y = $sector->{y} if $max_y < $sector->{y};
        $min_x = $sector->{x} if $min_x > $sector->{x};
        $min_y = $sector->{y} if $min_y > $sector->{y};
    }
    
    $c->session->{mapped_dungeon_boundaries} = {
    	min_x => $min_x,
    	max_x => $max_x,
    	min_y => $min_y,
    	max_y => $max_y,	
    };

    my $scroll_to = $c->forward('calculate_scroll_to', [$current_location]);
   
    $c->stash->{panel_callbacks} = [
    	{
        	name => 'dungeonRefresh',
        	data => $scroll_to,
    	}
    ];    
    
    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'dungeon/view.html',
                params   => {
                    grid                => $grid,
                    viewable_sectors    => $viewable_sectors,
                    max_x               => $max_x,
                    max_y               => $max_y,
                    min_x               => $min_x,
                    min_y               => $min_y,
                    positions           => \@positions,
                    current_location    => $current_location,
                    allowed_to_move_to  => $allowed_to_move_to,
                    cgs                 => $cgs,
                    parties             => $parties,
                    allowed_move_hashes => $c->flash->{allowed_move_hashes},
                    in_combat           => $c->stash->{party} ? $c->stash->{party}->in_combat_with : undef,
                    zoom_level => $c->session->{zoom_level} || 2,
                    scroll_to => $scroll_to,
                    create_tooltips => 1,
                    dungeon_type => $c->stash->{dungeon_type},
                    tileset => $c->stash->{dungeon}->tileset,
                },
                return_output => 1,
            }
        ]
    );
}

sub move_to : Local {
    my ( $self, $c, $sector_id, $turn_cost ) = @_;

    $sector_id ||= $c->req->param('sector_id');
    
    $turn_cost //= 1;

    my $current_location = $c->model('DBIC::Dungeon_Grid')->find( 
    	{ dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, }, 
    	{ prefetch => {'dungeon_room' => 'dungeon'} } 
	);
	
	if (! $current_location) {
        # No longer in the dungeon?
        $c->forward( '/panel/refresh', [ 'messages', 'party_status', 'map' ] );
        return;
	}
	
	$c->stash->{dungeon} = $current_location->dungeon_room->dungeon;
	$c->stash->{dungeon_type} = $c->stash->{dungeon}->type;

    my $sector = $c->model('DBIC::Dungeon_Grid')->find( { 'dungeon_grid_id' => $sector_id, }, { prefetch => 'dungeon_room', } );

    croak "Can't find sector: $sector_id" unless $sector;

    $c->log->debug( "Attempting to move to " . $sector->x . ", " . $sector->y );

    # Check they're moving to a sector in the dungeon they're currently in
    if ( $current_location->dungeon_room->dungeon_id != $sector->dungeon_room->dungeon_id ) {
        croak "Can't move to sector: $sector_id - in the wrong dungeon";
    }

	# Check sector is in range.
    if (! $current_location->has_path_to($sector_id, 3)) {
        $c->stash->{error} = "You must be in range of the sector";
    }
    elsif ( $c->stash->{party}->turns < $turn_cost ) {
        $c->stash->{error} = "You do not have enough turns to move there";
    }
    # Can't move if a character is overencumbered
    elsif ( $c->stash->{party}->has_overencumbered_character ) {
    	$c->stash->{error} = "One or more characters are carrying two much equipment. Your party cannot move"; 
	}   
    
    else {
    	# If there's a teleporter here, they actually get moved to the destination of the teleporter
    	if (my $teleporter = $sector->teleporter) {
    		$sector_id = $teleporter->destination_id;
    		
    		unless ($sector_id) {
    			# Random teleporter - find a destination
    			my $random_dest = $c->model('DBIC::Dungeon_Grid')->find_random_sector( $sector->dungeon_room->dungeon_id );
    			$sector_id = $random_dest->id;
    		}
    		
    		push @{$c->stash->{messages}}, "You are teleported to elsewhere in the dungeon....";
    	}
    	else {    	
	    	$c->forward( '/' . $c->stash->{dungeon_type} . '/check_for_creature_move', [$sector] );
	
	       	my $creature_group = $c->forward( '/dungeon/combat/check_for_attack', [$sector] );
	
	        # If creatures attacked, refresh party panel
	        if ($creature_group) {
	            push @{ $c->stash->{refresh_panels} }, 'party';
	        }
    	}
    	
    	if ($sector->dungeon_room->special_room_id && 
    	   ! $c->session->{special_room_alerts}{$sector->dungeon_room_id} && $sector->dungeon_room_id != $current_location->dungeon_room_id) {
            # They're moving into a special room for the first time in this session, so send an alert.            
            my $message = $c->forward(
                'RPG::V::TT',
                [
                    {
                        template => 'dungeon/special_room_alert.html',
                        params   => {
                            room => $sector->dungeon_room,
                        },
                        return_output => 1,
    	            },
    	        ]
    	    );
    	    
    	    push @{$c->stash->{messages}}, $message;
    	    
    	    # Remember this, so we don't alert again in the session
    	    $c->session->{special_room_alerts}{$sector->dungeon_room_id} = 1;
    	}

        $c->stash->{party}->dungeon_grid_id($sector_id);
        $c->stash->{party}->turns( $c->stash->{party}->turns - $turn_cost );
        $c->stash->{party}->update;
        $c->stash->{party}->discard_changes;
        
        my $sectors = $c->forward('build_updated_sectors_data', [$current_location, $sector_id]);
        
        if ($sectors) {
	        $c->stash->{panel_callbacks} = [
	        	{
	        		name => 'dungeon',
	        		data => $sectors,
	        	}
	        ];
        }
    }

    $c->forward( '/panel/refresh', [ 'messages', 'party_status' ] );
}

# Build the sector data that the party can now view. i.e. only the sectors that
#  have changed as a result of the party's move (e.g. monsters, or what they can see)
sub build_updated_sectors_data : Private {
	my ($self, $c, $current_location, $sector_id) = @_;
	
	my $new_location = $c->model('DBIC::Dungeon_Grid')->find($sector_id);
	
	my $grids = $c->forward('build_viewable_sector_grids', [$new_location]);
	my ($sectors_to_update, $viewable_sector_grid, $allowed_to_move_to, $cgs, $parties) = @$grids;
	
	my $sectors_to_update_grid;
	foreach my $sector (@$sectors_to_update) {
		$sectors_to_update_grid->[$sector->{x}][$sector->{y}] = $sector;		
	}
	
	# Check for a sector to update outside of the original map boundaries. If we find one, we give up and just refresh
	#  the panel. Haven't figured out a way to add sectors outside the boundary and have them displaybale (they can
	#  be created, but can't be scrolled to). If I could find a way to do it, it'd be better not to use this bail out
	#  option, since it's a lot slower to redraw the whole map (that's the whole point of updating the sectors individually)
	my $bail_out = 0;
	my $boundary_tl = {
		x => $c->session->{mapped_dungeon_boundaries}{min_x},
		y => $c->session->{mapped_dungeon_boundaries}{min_y},
	};
	my $boundary_br = {
		x => $c->session->{mapped_dungeon_boundaries}{max_x},
		y => $c->session->{mapped_dungeon_boundaries}{max_y},
	};	
	
	foreach my $sector (@$sectors_to_update) {
		# Don't let sectors out of the viewable area cause us to bail out. If you can't see it, you don't need to
		#  update it
		next unless $viewable_sector_grid->[$sector->{x}][$sector->{y}];
		
		if (! RPG::Map->is_in_range($sector, $boundary_tl, $boundary_br)) {
			$c->log->info( $sector->{x} . ", " . $sector->{y} . " out of range, bailing out of quick sector update");
			$c->stash->{saved_grid} = $grids; # Can use these later
			$bail_out = 1;
			last;				
		}
	}
	
	if ($bail_out) {
		push @{ $c->stash->{refresh_panels} }, 'map';
		return;
	}
	
	my @positions = map { $_->position } $c->model('DBIC::Dungeon_Position')->search;
	
	my $sectors;
	my $cg_descs;

	my ( $top_corner, $bottom_corner ) = RPG::Map->surrounds_by_range( $new_location->x, $new_location->y, 3 );
	for my $y ($top_corner->{y} .. $bottom_corner->{y}) {
		for my $x ($top_corner->{x} .. $bottom_corner->{x}) {	
			my $current_sector = $sectors_to_update_grid->[$x][$y];
			
			next unless $current_sector;

			# Only sectors in allowed_to_move_to or viewable area (or current location) should be updated
			next unless $allowed_to_move_to->{$current_sector->{dungeon_grid_id}} ||
				($new_location->x == $x && $new_location->y == $y);
				
			# If sector is not viewable, but is moveable, check if sector is mapped by party. Only display mapped
			#  sectors (viewable sectors are always mapped)
			unless ($viewable_sector_grid->[$x][$y] || $c->model('DBIC::Mapped_Dungeon_Grid')->find(
				{
					dungeon_grid_id => $current_sector->{dungeon_grid_id},
					party_id => $c->stash->{party}->id,
				}
			)) {
				next;
			}							

			my %sector_data;
				
			$sector_data{sector} = $c->forward(
		        'RPG::V::TT',
		        [
		            {
		                template => 'dungeon/map_sector.html',
		                params   => {
		                	sector => $current_sector,
		                	cgs => $cgs,
		                	parties => $parties,
		                	allowed_to_move_to => $allowed_to_move_to,
		                	viewable_sectors => $viewable_sector_grid,
		                	x => $x,
		                	y => $y,
		                	current_location => $new_location,
		                	zoom_level => $c->session->{zoom_level} || 2,
		                	allowed_move_hashes => $c->flash->{allowed_move_hashes},
		                	positions => \@positions,      
		                	dungeon_type => $c->stash->{dungeon_type},
		                	tileset => $c->stash->{dungeon}->tileset,
		                },
		                return_output => 1,
		            }
		        ]
    		);				
    		
    		# Get description if there's a CG here.
    		if (my $cg = $cgs->[$x][$y]) {
	    		$sector_data{cg_desc} = $c->forward(
			        'RPG::V::TT',
			        [
			            {
			                template => 'combat/creature_group_summary.html',
			                params   => {
			                	creature_group => $cg,
			                },
			                return_output => 1,
			            }
			        ]
	    		);	
    		}
    		
    		# Get description if there's a party here.
    		if (my $party = $parties->[$x][$y]) {
	    		$sector_data{party_desc} = $c->forward(
			        'RPG::V::TT',
			        [
			            {
			                template => 'party/summary.html',
			                params   => {
			                	party => $party,
			                },
			                return_output => 1,
			            }
			        ]
	    		);	
    		}    		
    		
    		$sectors->[$x][$y] = \%sector_data;
    		
    		
		}		
	}
	
	# Clear any other sectors that were previously in the viewable area.
	( $top_corner, $bottom_corner ) = RPG::Map->surrounds_by_range( $current_location->x, $current_location->y, 3 );
    my @old_sectors = $c->model('DBIC::Dungeon_Grid')->search(
        {
            x                         => { '>=', $top_corner->{x}, '<=', $bottom_corner->{x} },
            y                         => { '>=', $top_corner->{y}, '<=', $bottom_corner->{y} },
            'dungeon_room.dungeon_id' => $current_location->dungeon_room->dungeon_id,
            'dungeon_room.floor'      => $current_location->dungeon_room->floor,
            party_id                  => $c->stash->{party}->id,
        },
        {
            join     => [ 'dungeon_room', 'mapped_dungeon_grid' ],
            prefetch => ['treasure_chest', 'teleporter'],
        },
    );
	my $old_sectors_grid;
	foreach my $sector (@old_sectors) {
		$old_sectors_grid->[$sector->x][$sector->y] = $sector;		
	}    
	
	for my $y ($top_corner->{y} .. $bottom_corner->{y}) {
		for my $x ($top_corner->{x} .. $bottom_corner->{x}) {
						
			# If we've already added something in the sector, leave it as is.
			next if $sectors->[$x][$y];
			
			# If the sector doesn't exist, we can skip it
			next unless $old_sectors_grid->[$x][$y];
			
			$sectors->[$x][$y]{sector} = $c->forward(
		        'RPG::V::TT',
		        [
		            {
		                template => 'dungeon/map_sector.html',
		                params   => {
		                	sector => $old_sectors_grid->[$x][$y],
		                	cgs => $cgs,
		                	parties => $parties,
		                	allowed_to_move_to => $allowed_to_move_to,
		                	viewable_sector_grid => $viewable_sector_grid,
		                	x => $x,
		                	y => $y,
		                	current_location => $new_location,
		                	zoom_level => $c->session->{zoom_level} || 2,
		                	allowed_move_hashes => $c->flash->{allowed_move_hashes},
		                	positions => \@positions,
		                	create_tooltips => 0,
		                	dungeon_type => $c->stash->{dungeon_type},
		                	tileset => $c->stash->{dungeon}->tileset,
		                	
		                },
		                return_output => 1,
		            }
		        ]
    		);			
		}
	}
		
	my $scroll_to = $c->forward('calculate_scroll_to', [$new_location, $current_location]);
		
	return {
		sectors => $sectors,
		scroll_to => $scroll_to,
		boundaries => $c->session->{mapped_dungeon_boundaries},
	};
	
}

sub calculate_scroll_to : Private {
	my ($self, $c, $location, $from) = @_;
	
	my $x_modifier = 4;
	my $y_modifier = 4;
	my $boundaries = $c->session->{mapped_dungeon_boundaries};
	
	if ($from) {
		if ($from->x > $location->x) {
			$x_modifier = -4;
		}
		if ($from->y > $location->y) {
			$y_modifier = -4;
		}
	}
	else {
		# Not moving from a location. Make sure we scroll in the right
		#  direction if it's near the edge of the map
		if ($location->x - $x_modifier < $boundaries->{min_x}) {
			$x_modifier = -4;	
		}
		if ($location->y - $y_modifier < $boundaries->{min_y}) {
			$y_modifier = -4;	
		}
	}
		
	
	my $scroll_to = {
		x => $location->x + $x_modifier,
		y => $location->y + $y_modifier,
	};

	if ($scroll_to->{x} < $boundaries->{min_x}) {
		$scroll_to->{x} = $boundaries->{min_x};
	}
	if ($scroll_to->{x} > $boundaries->{max_x}) {
		$scroll_to->{x} = $boundaries->{max_x};
	}
	if ($scroll_to->{y} < $boundaries->{min_y}) {
		$scroll_to->{y} = $boundaries->{min_y};
	}
	if ($scroll_to->{y} > $boundaries->{max_y}) {
		$scroll_to->{y} = $boundaries->{max_y};
	}		
	
	return $scroll_to;
}

sub check_for_creature_move : Private {
    my ( $self, $c, $current_location ) = @_;

    my @creatures_in_room =
        $c->model('DBIC::CreatureGroup')
        ->search( { 'dungeon_grid.dungeon_room_id' => $current_location->dungeon_room_id, }, { prefetch => 'dungeon_grid', }, );
        
    $c->forward('move_creatures', [$current_location, \@creatures_in_room, $c->config->{creature_move_chance_on_party_move}]);
}

sub move_creatures : Private {
	my ( $self, $c, $current_location, $creatures_in_room, $move_chance, $max_move ) = @_;
	
	$max_move ||= 1;
	
	confess "Current location not supplied" unless $current_location;
	confess "Creatures in room not supplied" unless $creatures_in_room;
	confess "Move chance not supplied" unless $move_chance;
	
    my @possible_sectors = $c->model('DBIC::Dungeon_Grid')->search(
        {
            'dungeon_room_id'                  => $current_location->dungeon_room_id,
            'creature_group.creature_group_id' => undef,
        },
        { join => 'creature_group' }
    );

    foreach my $cg (@$creatures_in_room) {
        next if $cg->in_combat_with;

        next if Games::Dice::Advanced->roll('1d100') > $move_chance;

		my @move_range = RPG::Map->surrounds_by_range($cg->dungeon_grid->x, $cg->dungeon_grid->y, $max_move);

        my @sectors = shuffle grep { RPG::Map->is_in_range({ x=>$_->x, y=>$_->y}, @move_range) } @possible_sectors;

        return unless @sectors;
        
        my $sector_to_move_to = $sectors[0];

        if ($sector_to_move_to) {
            $cg->dungeon_grid_id( $sector_to_move_to->id );
            $cg->update;
        }
    }	
}

sub open_door : Local {
    my ( $self, $c ) = @_;

    my ($door) = $c->model('DBIC::Door')->search( 
        {
            door_id => $c->req->param('door_id'),
            'dungeon_grid_id' => $c->stash->{party}->dungeon_grid_id,
        },
    );

    if ( !$door || !$door->can_be_passed ) {
        croak "Cannot open door";
    }

    my ( $opposite_x, $opposite_y ) = $door->opposite_sector;

    $c->log->debug("Opening door, and moving to sector: $opposite_x, $opposite_y");

    my $sector_to_move_to = $c->model('DBIC::Dungeon_Grid')->find(
        {
            x                         => $opposite_x,
            y                         => $opposite_y,
            'dungeon_room.dungeon_id' => $door->dungeon_grid->dungeon_room->dungeon_id,
            'dungeon_room.floor'      => $door->dungeon_grid->dungeon_room->floor,
        },
        { join => 'dungeon_room', }
    );

    $c->forward( 'move_to', [ $sector_to_move_to->id ] );
}

sub sector_menu : Local {
    my ( $self, $c ) = @_;

    my $current_location =
        $c->model('DBIC::Dungeon_Grid')->find( 
        	{ 
        		dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, 
        	}, 
        	{ 
        		prefetch => [
        			{'doors' => 'position'},
        			'treasure_chest',
        			{'dungeon_room' => 'dungeon'},
        		],        		
       		} 
       	);

    my $creature_group = $current_location->available_creature_group;

    my @doors = $current_location->available_doors;

    my $parties_in_sector = $c->forward( '/party/parties_in_sector', [ undef, $current_location->id ] );

    my $creature_group_display = $c->forward( '/combat/display_cg', [ $creature_group, 1 ] );

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'dungeon/sector.html',
                params   => {
                    doors                  => \@doors,
                    current_location       => $current_location,
                    creature_group_display => $creature_group_display,
                    creature_group         => $creature_group,
                    messages               => $c->stash->{messages},
                    parties_in_sector      => $parties_in_sector,
                    dungeon_type           => $current_location->dungeon_room->dungeon->type,
                    castle_move_type       => $c->session->{castle_move_type} || '',
                },
                return_output => 1,
            }
        ]
    );
}

sub unblock_door : Local {
    my ( $self, $c ) = @_;

    if ( $c->stash->{party}->turns <= 0 ) {
        $c->stash->{error} = "You don't have enough turns to attempt that";
        $c->detach( '/panel/refresh', ['messages'] );
    }

    my $current_location = $c->model('DBIC::Dungeon_Grid')->find( { dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, }, );

    my $door = $c->model('DBIC::Door')->find( { door_id => $c->req->param('door_id') } );

    croak "Door not in this sector" unless $current_location->id == $door->dungeon_grid_id;

    my %action_for_door = (
        charge => 'stuck',
        pick   => 'locked',
        break  => 'sealed',
    );

    my $success = 0;

    my ($character) = grep { $_->id == $c->req->param('character_id') } $c->stash->{party}->characters;
    
    croak "Character is dead" if $character->is_dead;

    # Only attempt to unblock door if action matches door's type
    if ( $action_for_door{ $c->req->param('action') } eq $door->type ) {

        my %stats = (
            charge => [ 'strength',     'constitution' ],
            pick   => [ 'agility',      'intelligence' ],
            break  => [ 'intelligence', 'divinity' ],
        );

        my $stats = $stats{ $c->req->param('action') };
        
        my ($stat1, $stat2) = @$stats;
        
        my $stat_avg = average $character->$stat1, $character->$stat2;

        my $roll_base              = 15;
        my $dungeon_level_addition = $current_location->dungeon_room->dungeon->level * 4;
        my $roll                   = Games::Dice::Advanced->roll( '1d' . $roll_base + $dungeon_level_addition );

        if ( $roll < $stat_avg ) {
            $success = 1;
            $door->state('open');
            $door->update;

            my $opposite_door = $door->opposite_door;
            $opposite_door->state('open');
            $opposite_door->update;

            $c->stash->{refresh_panels} = ['map'];
        }
    }

    my $message = $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'dungeon/unblock_door_message.html',
                params   => {
                    door      => $door,
                    success   => $success,
                    character => $character,
                    action    => $c->req->param('action'),
                },
                return_output => 1,
            }
        ]
    );

    $c->stash->{messages} = $message;

    $c->stash->{party}->turns( $c->stash->{party}->turns - 1 );
    $c->stash->{party}->update;

    $c->forward( '/panel/refresh', [ 'messages', 'party_status' ] );
}

sub take_stairs : Local {
    my ( $self, $c ) = @_;

    my $current_location = $c->model('DBIC::Dungeon_Grid')->find( { dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, }, );
    
    croak "No stairs here" unless $current_location->stairs_up || $current_location->stairs_down;
		
	my $dungeon = $current_location->dungeon_room->dungeon;

	if ($current_location->stairs_up && $current_location->dungeon_room->floor == 1) {		
    	my $type = $dungeon->type;

		$c->forward('/'. $type . '/exit', [undef, $dungeon]);
	}
	else {
		my $direction = $current_location->stairs_up ? -1 : 1;
		my $column = $current_location->stairs_up ? 'stairs_down' : 'stairs_up';
		
		my $new_sector = $c->model('DBIC::Dungeon_Grid')->find(
			{
				'dungeon_room.dungeon_id' => $dungeon->id,
				'dungeon_room.floor' => $current_location->dungeon_room->floor + $direction,
				$column => 1,
			},
			{
				join => 'dungeon_room',
			}
		);
		
		$c->stash->{party}->dungeon_grid_id($new_sector->id);
		$c->stash->{party}->update;
		
		$c->forward( '/panel/refresh', [ 'messages', 'party_status', 'map' ] );
	}

}

sub exit : Private {
	my ( $self, $c, $turn_cost ) = @_;
	
	$turn_cost ||= 1;
	
    # Reset zoom level
    $c->session->{zoom_level} = 2;

    $c->stash->{party}->dungeon_grid_id(undef);
    $c->stash->{party}->turns( $c->stash->{party}->turns - $turn_cost );
    $c->stash->{party}->update;
    
    undef $c->session->{spotted};

    $c->forward( '/panel/refresh', [ 'map', 'messages', 'party_status', 'zoom', 'party' ] );
}

sub search_room : Local {
    my ( $self, $c ) = @_;

    if ( $c->stash->{party}->turns <= 0 ) {
        $c->stash->{error} = "You don't have enough turns to attempt that";
        $c->detach( '/panel/refresh', ['messages'] );
    }

    my $current_location =
        $c->model('DBIC::Dungeon_Grid')
        ->find( { dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, }, { prefetch => { 'dungeon_room' => 'dungeon' }, }, );

    my $found_something        = 0;
    my @available_secret_doors = $c->model('DBIC::Door')->get_secret_doors_in_room( $current_location->dungeon_room_id );

    # Remove secret doors in sectors the party doesn't know about
    my @secret_doors;
    my %mapped_sectors_by_id = map { $_->id => 1 } $c->model('DBIC::Dungeon_Grid')->search(
        {
            party_id             => $c->stash->{party}->id,
            'dungeon.dungeon_id' => $current_location->dungeon_room->dungeon_id,
        },
        { join => [ { 'dungeon_room' => 'dungeon' }, 'mapped_dungeon_grid' ], }
    );

    foreach my $secret_door (@available_secret_doors) {
        if ( $mapped_sectors_by_id{ $secret_door->dungeon_grid_id } ) {
            push @secret_doors, $secret_door;
        }
    }

    if (@secret_doors) {
        my $avg_int = $c->stash->{party}->average_stat('intelligence');

        my $roll = Games::Dice::Advanced->roll( '1d' . ( 15 + ( $current_location->dungeon_room->dungeon->level * 5 ) ) );

        if ( $roll <= $avg_int ) {
            my $door_found = ( shuffle @secret_doors )[0];

            $door_found->state('open');
            $door_found->update;

            my $opposite_door = $door_found->opposite_door;
            $opposite_door->state('open');
            $opposite_door->update;

            $found_something = 1;

            $c->stash->{messages} = "You find a secret door to the " . $door_found->display_position . "!";
        }
    }

    unless ($found_something) {
        $c->stash->{messages} = "You don't find anything of interest.";
    }

    $c->stash->{party}->turns( $c->stash->{party}->turns - 1 );
    $c->stash->{party}->update;

    $c->forward( '/panel/refresh', [ 'map', 'messages', 'party_status' ] );
}

sub open_chest : Local {
    my ( $self, $c ) = @_;

    my $current_location = $c->model('DBIC::Dungeon_Grid')->find( 
    	{ dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, },
    	{
    		prefetch => {'treasure_chest' => 'items'},
    	},
    );

    croak "No chest here" unless $current_location->treasure_chest;
    
    if ($current_location->treasure_chest->trap) {
    	$c->detach('handle_chest_trap', [$current_location]);
    }

	my $chest = $current_location->treasure_chest;
	my @items = $chest->items;

	my @characters = $c->stash->{party}->characters;
	
	my @items_found;
	
	foreach my $item (@items) {
		# XXX: call find_dungeon_item quest hack, see method for details
		if ($self->hide_item_from_party($c, $item)) {
			$c->log->debug("Found a quest item for a quest not owned by this party.... skipping");
			next;			
		}
		
        my $finder;
        foreach my $character ( shuffle @characters ) {
            unless ( $character->is_dead ) {
                $finder = $character;
                last;
            }
        }		
        
        $item->add_to_characters_inventory($finder);
        
        push @items_found, {
        	character => $finder,
        	item => $item,
        };
	}
	
    my $message = $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'dungeon/open_chest.html',
                params   => {
                    items_found => \@items_found,
                    gold_found => $chest->gold,
                },
                return_output => 1,
            }
        ]
    );

    push @{$c->stash->{messages}},  $message;
    
    my $dungeon = $current_location->dungeon_room->dungeon;
    my $quest_messages = $c->forward( '/quest/check_action', [ 'chest_opened', $dungeon->id, \@items ] );
    
    push @{$c->stash->{messages}}, @$quest_messages;

	$c->stash->{party}->increase_gold($chest->gold);
    $c->stash->{party}->turns( $c->stash->{party}->turns - 1 );
    $c->stash->{party}->update;
    
    if ($chest->gold && $current_location->dungeon_room->dungeon->type eq 'castle') {
		my $messages = $c->forward( '/quest/check_action', ['town_raid', $current_location->dungeon_room->dungeon->town] );
		push @{ $c->stash->{messages} }, @$messages;	
    }
    
    $chest->gold(0);
    $chest->update;

    $c->forward( '/panel/refresh', [ 'messages', 'party_status' ] );
}

# XXX: this is a hack to get around the problem of parties picking up an item created for an item quest for a particular party
#  If an item has a name, we check if it's involved in a quest, and if the current party is the correct one. If not, the item
#  effectively invisible to this party.
sub hide_item_from_party {
	my ($self, $c, $item) = @_;
	
	return 0 unless $item->name;
	$c->log->debug("Deciding whether to hide item with id : " . $item->id);
	
	my $quest = $c->model('DBIC::Quest')->find(
		{
			'quest_param_name.quest_param_name' => 'Item',
			'quest_params.current_value' => $item->id,
			'type.quest_type' => 'find_dungeon_item',
		},
		{
			join => [
				'type',
				{'quest_params' => 'quest_param_name'},
			],
		}
	);
	
	return 0 unless $quest;
	$c->log->debug("Found quest with id: " . $quest->id);
	
	return 0 if $quest->party_id && $quest->party_id == $c->stash->{party}->id;
	$c->log->debug("Quest has party id: " . $quest->party_id) if defined $quest->party_id;
	
	return 1;
}

sub handle_chest_trap : Private {
	my ( $self, $c, $current_location ) = @_;
	
	my $avg_div = $c->stash->{party}->average_stat('divinity');
	unless ($c->session->{detected_trap}[$current_location->x][$current_location->y] || 
		Games::Dice::Advanced->roll('1d30') <= $avg_div) {
		# Failed to detect trap
		$c->detach('trigger_trap', [$current_location]);
	}
	
	$c->stash->{dialog_to_display} = 'chest-trap';
	
	$c->session->{detected_trap}[$current_location->x][$current_location->y] = 1;
	
	$c->forward( '/panel/refresh', [ 'messages' ] );	
}

sub disarm_trap : Local {
	my ( $self, $c ) = @_;
	
    my $current_location = $c->model('DBIC::Dungeon_Grid')->find( 
    	{ dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, },
    	{
    		prefetch => {'treasure_chest' => 'items'},
    	},
    );

    croak "No chest here" unless $current_location->treasure_chest;
    
    unless ($current_location->treasure_chest->trap) {
    	# Could have been someone else disarming it?
    	$c->stash->{messages} = "The trap seems to have disappeared on it's own";	
    	$c->detach( '/panel/refresh', [ 'messages' ] );
    }
    
    my $avg_int = $c->stash->{party}->average_stat('intelligence');
	if (Games::Dice::Advanced->roll('1d30') <= $avg_int) {
		$current_location->treasure_chest->trap(undef);
		$current_location->treasure_chest->update;
		
    	$c->stash->{messages} = "Trap disarmed!";	
    	$c->detach( '/panel/refresh', [ 'messages' ] );
	}
	else {
		$c->forward('trigger_trap', [$current_location]);
	}	
}

sub trigger_trap : Private {
	my ( $self, $c, $current_location ) = @_;

	my $chest = $current_location->treasure_chest;
	
	my $dungeon = $current_location->dungeon_room->dungeon;
	
	my $target = (shuffle(grep { ! $_->is_dead } $c->stash->{party}->characters))[0];
	my $trap_variable;
	
	given($chest->trap) {
		when ("Curse") {
			$trap_variable = Games::Dice::Advanced->roll('2d3') * $dungeon->level;
			$c->model('DBIC::Effect')->create_effect({
				effect_name => 'Cursed',
				target => $target,
				duration => $trap_variable,
				modifier => -8 * $dungeon->level,
				combat => 0,
				modified_state => 'attack_factor',					
			});	
		}
		
		when ("Hypnotise") {
			$trap_variable = Games::Dice::Advanced->roll('2d3') * $dungeon->level;
			$c->model('DBIC::Effect')->create_effect({
				effect_name => 'Hypnotised',
				target => $target,
				duration => $trap_variable,
				modifier => -4,
				combat => 0,
				modified_state => 'attack_frequency',					
			});	
		}	
		
		when ("Detonate") {
			$trap_variable = Games::Dice::Advanced->roll('2d4') * $dungeon->level;
			$target->hit($trap_variable);
		}				
	}
	
    my $message = $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'dungeon/trigger_chest_trap.html',
                params   => {
                    target => $target,
                    trap => $chest->trap,
                    trap_variable => $trap_variable,
                    
                },
                return_output => 1,
            }
        ]
    );

    $c->stash->{messages} = $message;	
	
	$current_location->treasure_chest->trap(undef);
	$current_location->treasure_chest->update;
	
    $c->detach( '/panel/refresh', [ 'messages', 'party' ] );
		
}
 

1;
