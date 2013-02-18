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

	my $grids = $c->forward('build_viewable_sector_grids', [$current_location]);
	my ($sectors, $viewable_sector_grid, $allowed_to_move_to, $cgs, $parties, $objects) = @$grids;

    my $mapped_sectors_by_coord;
    my $grid;
    
	# Add any sectors from viewable grid into mapped sectors, if they're not there already
	foreach my $sector (@$sectors) {
		if (! $mapped_sectors_by_coord->[ $sector->{x} ][ $sector->{y} ] && $viewable_sector_grid->[ $sector->{x} ][ $sector->{y} ]) {
			push @mapped_sectors, $sector;
		}	
	}
	
	my ( $min_x, $min_y, $max_x, $max_y ) = ( $mapped_sectors[0]->{x}, $mapped_sectors[0]->{y}, 0, 0 );
    
    # Build $gird to pass to the template, and calculate min/max x & y
    foreach my $sector (@mapped_sectors) {
        $c->session->{dungeon_mapped}{$sector->{dungeon_grid_id}} = 1;
        $mapped_sectors_by_coord->[ $sector->{x} ][ $sector->{y} ] = $sector; 
        
        $grid->[ $sector->{x} ][ $sector->{y} ] = $sector;

        $max_x = $sector->{x} if $max_x < $sector->{x};
        $max_y = $sector->{y} if $max_y < $sector->{y};
        $min_x = $sector->{x} if $min_x > $sector->{x};
        $min_y = $sector->{y} if $min_y > $sector->{y};
    }

    push @{$c->stash->{panel_callbacks}}, {
        name => 'setMinimapVisibility',
        data => 0,
    };	
  
    my @positions = map { $_->position } $c->model('DBIC::Dungeon_Position')->search;

    $c->session->{mapped_dungeon_boundaries} = {
    	min_x => $min_x,
    	max_x => $max_x,
    	min_y => $min_y,
    	max_y => $max_y,	
    };

    my $scroll_to = $c->forward('calculate_scroll_to', [$current_location]);
   
    push @{$c->stash->{panel_callbacks}}, {
        name => 'dungeonRefresh',
        data => $scroll_to,
    };
    
    my @viewable_sector_list;
    foreach my $sector (@$sectors) {
        push @viewable_sector_list, [$sector->{x}, $sector->{y}]
            if $viewable_sector_grid->[ $sector->{x} ][ $sector->{y} ];   
    }
    
    push @{$c->stash->{panel_callbacks}}, {
        name => 'dungeonSetViewable',
        data => \@viewable_sector_list,
    };
            
    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'dungeon/view.html',
                params   => {
                    grid                => $grid,
                    max_x               => $max_x,
                    max_y               => $max_y,
                    min_x               => $min_x,
                    min_y               => $min_y,
                    positions           => \@positions,
                    current_location    => $current_location,
                    allowed_to_move_to  => $allowed_to_move_to,
                    cgs                 => $cgs,
                    parties             => $parties,
                    objects             => $objects,
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
    
    $c->log->debug("Got sectors allowed to move to");
    
    $c->stats->profile("Queried sectors allowed to move to");

	my $allowed_to_move_to = $current_location->sectors_allowed_to_move_to( $c->config->{dungeon_move_maximum} );

    $c->log->debug("Built allowed to move to hash");

    $c->stats->profile("Built allowed to move to hash");
	
    # Get cgs in viewable area
    $c->log->debug("Building viewable CGs");
    my $cgs;
    my @cg_recs = $c->model('DBIC::Dungeon_Grid')->search(
        {
            x                              => { '>=', $top_corner->{x}, '<=', $bottom_corner->{x} },
            y                              => { '>=', $top_corner->{y}, '<=', $bottom_corner->{y} },
            'dungeon_room.dungeon_room_id' => $current_location->dungeon_room_id,
            'dungeon_room.floor'           => $current_location->dungeon_room->floor,
            'in_combat_with.party_id'      => [undef, $c->stash->{party}->id],
        },
        {
            prefetch => [ { 'creature_group' => { 'creatures' => 'type' } }, ],
            join     => ['dungeon_room', {'creature_group' => 'in_combat_with'}],
        },
    );
    $c->stats->profile("Queried CGs");	
    
    foreach my $cg_rec (@cg_recs) {
        my $cg = $cg_rec->creature_group;
        
        next unless $cg;
        
        my $group_size = $cg->number_alive;
        
        next if $group_size <= 0;
        
        if ($group_size <= 3) {
            $cg->{group_size} = '1';
        }
        elsif ($group_size <= 6) {
            $cg->{group_size} = '2';   
        }
        else {
            $cg->{group_size} = '3';
        }
        
        if ($cg->has_mayor) {
            $cg->{group_img} = 'mayor';
        }
        else {        
            # Find category of first creatures
            my $cret = ($cg->creatures)[0];
            if ($cret) {
                my $category = $cret->type->category;
                $cg->{group_img} = $category->dungeon_group_img;
            }
        }
        
        $cgs->[ $cg_rec->x ][ $cg_rec->y ] = $cg;
    }
 
    $c->stats->profile("Got CGs");	

	# Get parties in viewable area
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
            my $group_size = $parties[0]->number_alive;
            if ($group_size <= 3) {
                $parties[0]->{group_size} = '1';
            }
            elsif ($group_size <= 6) {
                $parties[0]->{group_size} = '2';   
            }
            else {
                $parties[0]->{group_size} = '3';
            }            
        }
        
        $parties->[ $party_rec->x ][ $party_rec->y ] = \@parties;
    }
 
    $c->stats->profile("Got Parties");
    
    my $objects;
    my $objects_rs = $c->model('DBIC::Dungeon_Grid')->search(
        {
            'x'               => { '>=', $top_corner->{x}, '<=', $bottom_corner->{x} },
            'y'               => { '>=', $top_corner->{y}, '<=', $bottom_corner->{y} },
            'dungeon_room.dungeon_room_id' => $current_location->dungeon_room_id,
            'dungeon_room.floor'           => $current_location->dungeon_room->floor,
        },
        {
            prefetch => ['dungeon_room', 'teleporter', 'treasure_chest', 'bomb'],
        },
    );
    
    $objects_rs->result_class('DBIx::Class::ResultClass::HashRefInflator'); 
    
    while (my $object = $objects_rs->next) {
        next unless $object->{bomb} || $object->{teleporter} || $object->{treasure_chest};        
        $objects->[ $object->{x} ][ $object->{y} ] = $object;
    }
    
    $c->stats->profile("Got Objects");
    $c->log->debug("Getting viewable sectors");
	
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
        if (! $c->session->{dungeon_mapped}{$sector->{dungeon_grid_id}}) {

            my $mapped = $c->model('DBIC::Mapped_Dungeon_Grid')->find_or_create(
    	        {
        	        party_id        => $c->stash->{party}->id,
                    dungeon_grid_id => $sector->{dungeon_grid_id},
                }
            );            
        } 
    }
        
    my $viewable_sectors_by_coord;
    foreach my $viewable_sector (@viewable_sectors) {
        $viewable_sectors_by_coord->[ $viewable_sector->{x} ][ $viewable_sector->{y} ] = 1;
    }    
    
    $c->stats->profile("Got viewable sectors");

    return [\@sectors, $viewable_sectors_by_coord, $allowed_to_move_to, $cgs, $parties, $objects];		
}

sub move_to : Local {
    my ( $self, $c, $sector_id, $turn_cost ) = @_;

    if ($c->stash->{party}->in_combat) {
        croak "Can't move while in combat";   
    }

    $sector_id ||= $c->req->param('sector_id');
    
    $turn_cost //= $c->config->{cost_of_moving_through_dungeons};

    my $current_location = $c->model('DBIC::Dungeon_Grid')->find( 
    	{ dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, }, 
    	{ prefetch => {'dungeon_room' => 'dungeon'} } 
	);
	
	if (! $current_location) {
        # No longer in the dungeon?
        $c->forward( '/panel/refresh', [ 'messages', 'party_status', 'map', 'creatures' ] );
        return;
	}
	
	$c->stash->{dungeon} = $current_location->dungeon_room->dungeon;
	$c->stash->{dungeon_type} = $c->stash->{dungeon}->type;

    my $sector = $c->model('DBIC::Dungeon_Grid')->find( { 'dungeon_grid_id' => $sector_id, }, { prefetch => 'dungeon_room', } );

    croak "Can't find sector: $sector_id" unless $sector;

    #$c->log->debug( "Attempting to move to " . $sector->x . ", " . $sector->y );

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
    	if ($sector->dungeon_room->special_room_id 
    	   && ! $c->session->{special_room_alerts}{$sector->dungeon_room_id}
    	   && $sector->dungeon_room_id != $current_location->dungeon_room_id
    	   && $sector->dungeon_room->is_active) {
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
        
        my $quick_refresh = 1;
        
    	# If there's a teleporter here, they actually get moved to the destination of the teleporter
    	if (my $teleporter = $sector->teleporter) {
    	    my $teleporter_dest = $teleporter->destination;    		
    		
    		unless ($teleporter_dest) {
    			# Random teleporter - find a destination
    			$teleporter_dest = $c->model('DBIC::Dungeon_Grid')->find_random_sector( $sector->dungeon_room->dungeon_id );    			
    		}    		
    		
    		$sector_id = $teleporter_dest->dungeon_grid_id;
    		
    		if ($teleporter_dest->dungeon_room->floor != $sector->dungeon_room->floor) {
                push @{$c->stash->{refresh_panels}}, 'map';
                $quick_refresh = 0;            
    		} 
    		
    		push @{$c->stash->{messages}}, "You are teleported to elsewhere in the dungeon....";
    	}
    	else {    	
	    	$c->forward( '/' . $c->stash->{dungeon_type} . '/check_for_creature_move', [$sector] );
	
	       	my $creature_group = $c->forward( '/dungeon/combat/check_for_attack', [$sector] );
	
	        if ($creature_group) {
       	        # If creatures attacked, refresh party panel
	            push @{ $c->stash->{refresh_panels} }, 'party';
	            
	            # Store any messages for later (usually the special room message)
	            $c->session->{temp_dungeon_messages} = $c->stash->{messages};
	        }
    	}

        $c->stash->{party}->dungeon_grid_id($sector_id);
        $c->stash->{party}->turns( $c->stash->{party}->turns - $turn_cost );
        $c->stash->{party}->update;
        $c->stash->{party}->discard_changes;
        
        if ($quick_refresh) {
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
    }

    $c->forward( '/panel/refresh', [ 'messages', 'party_status', 'creatures' ] );
}

# Build the sector data that the party can now view. i.e. only the sectors that
#  have changed as a result of the party's move (e.g. monsters, or what they can see)
sub build_updated_sectors_data : Private {
	my ($self, $c, $current_location, $sector_id) = @_;
	
	my $new_location = $c->model('DBIC::Dungeon_Grid')->find($sector_id);
	
	my $grids = $c->forward('build_viewable_sector_grids', [$new_location]);
	my ($sectors_to_update, $viewable_sector_grid, $allowed_to_move_to, $cgs, $parties, $objects) = @$grids;
	
	my $sectors_to_update_grid;
	foreach my $sector (@$sectors_to_update) {
		$sectors_to_update_grid->[$sector->{x}][$sector->{y}] = $sector;		
	}
		
	# Check if we've gone beyond the displayed boundaries	
	my ($min_x_change, $max_x_change) = (0,0);
	my ($min_y_change, $max_y_change) = (0,0);	
	my ($new_min_x, $new_max_x, $new_min_y, $new_max_y);
	foreach my $sector (@$sectors_to_update) {
		next unless $viewable_sector_grid->[$sector->{x}][$sector->{y}];
		
		if ($sector->{x} < $c->session->{mapped_dungeon_boundaries}{min_x}) {
		    if (! defined $new_min_x || $sector->{x} < $new_min_x) {
                $new_min_x = $sector->{x};
                $min_x_change = $c->session->{mapped_dungeon_boundaries}{min_x} - $new_min_x;
		    }
		}
		
		if ($sector->{x} > $c->session->{mapped_dungeon_boundaries}{max_x}) {
		    if (! defined $new_max_x || $sector->{x} > $new_max_x) {
		        $new_max_x = $sector->{x};
		        $max_x_change = $new_max_x - $c->session->{mapped_dungeon_boundaries}{max_x};
		    }
		}
		
		if ($sector->{y} < $c->session->{mapped_dungeon_boundaries}{min_y}) {
		    if (! defined $new_min_y || $sector->{y} < $new_min_y) {
                $new_min_y = $sector->{y};
                $min_y_change = $c->session->{mapped_dungeon_boundaries}{min_y} - $new_min_y;
		    }
		    
		}
		
		if ($sector->{y} > $c->session->{mapped_dungeon_boundaries}{max_y}) {
		    if (! defined $new_max_y || $sector->{y} > $new_max_y) {
		        $new_max_y = $sector->{y};
		        $max_y_change = $new_max_y - $c->session->{mapped_dungeon_boundaries}{max_y};                
		    }
		}						
	}
	
	$c->session->{mapped_dungeon_boundaries}{min_x} = $new_min_x if defined $new_min_x;
	$c->session->{mapped_dungeon_boundaries}{max_x} = $new_max_x if defined $new_max_x;
	$c->session->{mapped_dungeon_boundaries}{min_y} = $new_min_y if defined $new_min_y;
	$c->session->{mapped_dungeon_boundaries}{max_y} = $new_max_y if defined $new_max_y;
	
	$c->stats->profile("Calculated boundary changes");

    # TODO: cache me
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
			# TODO: should be optimised
			unless ($viewable_sector_grid->[$x][$y] || $c->model('DBIC::Mapped_Dungeon_Grid')->find(
				{
					dungeon_grid_id => $current_sector->{dungeon_grid_id},
					party_id => $c->stash->{party}->id,
				}
			)) {
				next;
			}							

			my %sector_data;
			
			$sector_data{viewable} = 1 if $viewable_sector_grid->[$x][$y];
			$sector_data{allowed_to_move_to} = 1 if $allowed_to_move_to->{$current_sector->{dungeon_grid_id}};
			
            if (! $c->session->{dungeon_mapped}{$current_sector->{dungeon_grid_id}}) {
    			$sector_data{sector} = $c->forward(
    		        'RPG::V::TT',
    		        [
    		            {
    		                template => 'dungeon/map_sector.html',
    		                params   => {
    		                	sector => $current_sector,
    		                	cgs => $cgs,
    		                	parties => $parties,
    		                	objects => $objects,
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
        		$c->session->{dungeon_mapped}{$current_sector->{dungeon_grid_id}} = 1;
            }
            
            elsif ($cgs->[$x][$y] || $parties->[$x][$y] || $objects->[$x][$y]) {
                $sector_data{contents} = $c->forward(
    		        'RPG::V::TT',
    		        [
    		            {
    		                template => 'dungeon/sector_contents.html',
    		                params   => {
    		                	sector => $current_sector,
    		                	cgs => $cgs,
    		                	parties => $parties,
    		                	objects => $objects,    		                	
    		                	x => $x,
    		                	y => $y,
    		                	zoom_level => $c->session->{zoom_level} || 2,    		                	
    		                },
    		                return_output => 1,
    		            }
    		        ]
        		); 
            }
    		
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
	
	$c->stats->profile("Calculated sector data");
		
	my $scroll_to = $c->forward('calculate_scroll_to', [$new_location, $current_location]);
		
	return {
		sectors => $sectors,
		scroll_to => $scroll_to,
		new_location => {
		    x => $new_location->x,
		    y => $new_location->y,
		},
		min_x_change => $min_x_change,
		max_x_change => $max_x_change,
		min_y_change => $min_y_change,
		max_y_change => $max_y_change,
		dungeon_boundaries => $c->session->{mapped_dungeon_boundaries}
	};
	
}

sub calculate_scroll_to : Private {
	my ($self, $c, $location, $from) = @_;
	
	my $x_modifier = 10;
	my $y_modifier = 7;
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
        
        # Rare monsters / mayors not allowed to move out of room
        next if ($cg->has_rare_monster || $cg->has_mayor)
            && $sector_to_move_to->dungeon_room_id != $cg->dungeon_grid->dungeon_room_id;

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
    
    croak "Invalid door" unless $door;

    if ( ! $door->can_be_passed ) {
    	my $message = $c->forward(
    		'RPG::V::TT',
    		[
    			{
    				template => 'dungeon/unblock_door_diag.html',
    				params   => {
    					party => $c->stash->{party},
    					door => $door,
    					dismantle_cost => $c->config->{dismantle_door_cost},
    				},
    				return_output => 1,
    			}
    		]
    	);
    	
    	$c->forward('/panel/create_submit_dialog', 
    		[
    			{
    				content => $message,
    				submit_url => 'dungeon/unblock_door',
    				dialog_title => 'Unblock Door',
    			}
    		],
    	);    
    	
    	$c->forward( '/panel/refresh', [ 'messages' ] );
    	
    	return;    
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

    if ($c->session->{temp_dungeon_messages}) {
        $c->stash->{messages} = [$c->stash->{messages}] unless ref $c->stash->{messages} eq 'ARRAY';
        $c->stash->{messages} //= [];

        my $temp = ref $c->session->{temp_dungeon_messages} eq 'ARRAY' ? $c->session->{temp_dungeon_messages} : [$c->session->{temp_dungeon_messages}];
        push @{ $c->stash->{messages} }, @$temp;
        undef $c->session->{temp_dungeon_messages};
    }
    
    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'dungeon/sector.html',
                params   => {
                    doors                  => \@doors,
                    current_location       => $current_location,
                    creature_group         => $creature_group,
                    messages               => $c->stash->{messages},
                    parties_in_sector      => $parties_in_sector,
                    dungeon_type           => $current_location->dungeon_room->dungeon->type,
                    castle_move_type       => $c->session->{castle_move_type} || '',
                    has_watcher            => $c->stash->{party}->has_effect('Watcher'),
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

    if ( $c->req->param('action') eq 'dismantle' ) {
        if ( $c->stash->{party}->turns < $c->config->{dismantle_door_cost} ) {
            $c->stash->{error} = "You don't have enough turns to dismantle the door";
            $c->detach( '/panel/refresh', ['messages'] );
        }
        
        $c->stash->{messages} = "The party spends " . $c->config->{dismantle_door_cost} . " dismantling the door. It is now unblocked";
        
        $door->state('open');
        $door->update;
        
        my $opposite_door = $door->opposite_door;
        $opposite_door->state('open');
        $opposite_door->update;

        $c->stash->{refresh_panels} = ['map'];        
    
        $c->stash->{party}->turns( $c->stash->{party}->turns - $c->config->{dismantle_door_cost} );
        $c->stash->{party}->update;
    
        $c->detach( '/panel/refresh', [ 'messages', 'party_status' ] );        
        
    }

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
		
		$c->forward( '/panel/refresh', [ 'messages', 'party_status', 'map', 'creatures' ] );
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
    
    push @{$c->stash->{panel_callbacks}}, {
        name => 'setMinimapVisibility',
        data => 1,
    };    

    $c->forward( '/panel/refresh', [ 'map', 'messages', 'party_status', 'zoom', 'party', 'creatures' ] );
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
        my $bonus = $c->stash->{party}->skill_aggregate('Awareness', 'search_room');

        my $roll = Games::Dice::Advanced->roll( '1d' . ( 15 + ( $current_location->dungeon_room->dungeon->level * 5 ) ) );

        if ( $roll <= $avg_int + $bonus) {
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
    
	if ($c->stash->{party}->turns <= 0) {
		$c->stash->{error} = "You do not have enough turns to open the chest";
		$c->forward( '/panel/refresh', ['messages'] );
		return;   
	}    
    
    if ($current_location->treasure_chest->trap) {
    	$c->detach('handle_chest_trap', [$current_location]);
    }

	my $chest = $current_location->treasure_chest;
	my @items = $chest->items;
	
	my @items_found;
	
	foreach my $item (@items) {
		# XXX: call find_dungeon_item quest hack, see method for details
		if ($self->hide_item_from_party($c, $item)) {
			$c->log->debug("Found a quest item for a quest not owned by this party.... skipping");
			next;			
		}
		
        my $finder = $c->stash->{party}->give_item_to_character($item);
        
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
	my $bonus = $c->stash->{party}->skill_aggregate('Awareness', 'chest_trap');
	
	unless ($c->session->{detected_trap}[$current_location->x][$current_location->y] || 
		Games::Dice::Advanced->roll('1d30') <= $avg_div + $bonus) {
		# Failed to detect trap
		$c->forward('trigger_trap', [$current_location]);
		return;
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
	
	$c->forward('execute_trap', [$chest->trap, $dungeon->level]);
	
	$current_location->treasure_chest->trap(undef);
	$current_location->treasure_chest->update;
	
    $c->detach( '/panel/refresh', [ 'messages', 'party' ] );		
}

sub execute_trap : Private {
    my ($self, $c, $trap_type, $level) = @_;

	my $target = (shuffle(grep { ! $_->is_dead } $c->stash->{party}->characters))[0];
	my $trap_variable;
    
	given($trap_type) {
		when ("Curse") {
			$trap_variable = Games::Dice::Advanced->roll('2d3') * $level;
			$c->model('DBIC::Effect')->create_effect({
				effect_name => 'Cursed',
				target => $target,
				duration => $trap_variable,
				modifier => -8 * $level,
				combat => 0,
				modified_state => 'attack_factor',					
			});	
		}
		
		when ("Hypnotise") {
			$trap_variable = Games::Dice::Advanced->roll('2d3') * $level;
			$c->model('DBIC::Effect')->create_effect({
				effect_name => 'Hypnotised',
				target => $target,
				duration => $trap_variable,
				modifier => -4,
				combat => 0,
				modified_state => 'attack_frequency',					
			});	
		}	
		
		when ("Mute") {
			$trap_variable = Games::Dice::Advanced->roll('2d3') * $level;
			$c->model('DBIC::Effect')->create_effect({
				effect_name => 'Muted',
				target => $target,
				duration => $trap_variable,
				modifier => 0,
				combat => 0,
				modified_state => 'block_spell_casting',					
			});	
		}			
		
		when ("Detonate") {
			$trap_variable = Games::Dice::Advanced->roll('2d4') * $level;
			$target->hit($trap_variable, undef, 'an explosion');
		}				
	}
	
    my $message = $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'dungeon/trigger_chest_trap.html',
                params   => {
                    target => $target,
                    trap => $trap_type,
                    trap_variable => $trap_variable,
                    
                },
                return_output => 1,
            }
        ]
    );

    push @{$c->stash->{messages}}, $message;
    
    push @{$c->stash->{refresh_panels}}, 'party';
     
}
 

1;
