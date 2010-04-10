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

    my $current_location =
        $c->model('DBIC::Dungeon_Grid')->find( { dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, }, { prefetch => 'dungeon_room', } );

    $c->log->debug( "Current location: " . $current_location->x . ", " . $current_location->y );

    # Get all sectors that the party has mapped
    $c->log->debug("Getting mapped sectors");
    my @mapped_sectors = $c->model('DBIC::Dungeon_Grid')->get_party_grid( $c->stash->{party}->id, $current_location->dungeon_room->dungeon_id );

    $c->stats->profile("Queried map sectors");

    my $mapped_sectors_by_coord;
    foreach my $sector (@mapped_sectors) {
        $mapped_sectors_by_coord->[ $sector->{x} ][ $sector->{y} ] = $sector;
    }

	my $grids = $c->forward('build_viewable_sector_grids', [$current_location]);
	my ($sectors, $viewable_sector_grid, $allowed_to_move_to, $cgs, $parties) = @$grids;

    #warn "viewable sectors: " . scalar @viewable_sectors;

    $c->stats->profile("Saved newly discovered sectors");

    return $c->forward( 'render_dungeon_grid', [ $viewable_sector_grid, \@mapped_sectors, $allowed_to_move_to, $current_location, $cgs, $parties ] );
}

sub build_viewable_sector_grids : Private {
	my ($self, $c, $current_location) = @_;
	
	$c->stats->profile(start => "build_viewable_sector_grids");	
	
    # Find actual list of sectors party can move to
    my ( $top_corner, $bottom_corner ) = RPG::Map->surrounds_by_range( $current_location->x, $current_location->y, 3 );
    $c->log->debug("Getting sectors allowed to move to");
   
    my @sectors = $c->model('DBIC::Dungeon_Grid')->search(
        {
            x                         => { '>=', $top_corner->{x}, '<=', $bottom_corner->{x} },
            y                         => { '>=', $top_corner->{y}, '<=', $bottom_corner->{y} },
            'dungeon_room.dungeon_id' => $current_location->dungeon_room->dungeon_id,
        },
        {
            prefetch => [ 
            	'dungeon_room', 
            	{ 'doors' => 'position' },
            	{ 'walls' => 'position' }, 
            	{ 'party' => { 'characters' => 'class' } },
            	'treasure_chest' 
            ],

        },
    );
    
    $c->stats->profile("Queried sectors allowed to move to");

	my $allowed_to_move_to = $current_location->sectors_allowed_to_move_to( $c->config->{dungeon_move_maximum} );
    #my $allowed_to_move_to = $current_location->allowed_to_move_to_sectors( \@sectors, $c->config->{dungeon_move_maximum} );

    $c->stats->profile("Built allowed to move to hash");

    #$c->forward( 'store_allowed_move_hashes', [$allowed_to_move_to] );	
	
    # Get cgs in viewable area
    my $cgs;
    my @cg_recs = $c->model('DBIC::Dungeon_Grid')->search(
        {
            x                              => { '>=', $top_corner->{x}, '<=', $bottom_corner->{x} },
            y                              => { '>=', $top_corner->{y}, '<=', $bottom_corner->{y} },
            'dungeon_room.dungeon_room_id' => $current_location->dungeon_room_id,
        },
        {
            prefetch => [ { 'creature_group' => { 'creatures' => 'type' } }, ],
            join     => 'dungeon_room',
        },
    );
    foreach my $cg_rec (@cg_recs) {
        my $cg = $cg_rec->creature_group;
        $cg->{group_size} = scalar $cg->creatures if $cg;
        $cgs->[ $cg_rec->x ][ $cg_rec->y ] = $cg;
    }

    my $parties;	
    
    $c->stats->profile("Got CGs");	
	
    # Find viewable sectors, add newly discovered sectors to party's map, and get list of other parties nearby
    my @viewable_sectors;
    foreach my $sector (@sectors) {
        next unless $sector->dungeon_room_id == $current_location->dungeon_room_id;

        #$c->log->debug("Adding: " . $sector->x . ", " . $sector->y . " to viewable sectors");

        push @viewable_sectors, $sector;

        # Save newly mapped sectors 
        my $mapped = $c->model('DBIC::Mapped_Dungeon_Grid')->find_or_create(
	        {
    	        party_id        => $c->stash->{party}->id,
                dungeon_grid_id => $sector->dungeon_grid_id,
            }
        );
        
        if ( $sector->party && $sector->party->id != $c->stash->{party}->id ) {
            next if $sector->party->defunct;
            $parties->[ $sector->x ][ $sector->y ] = $sector->party;
        }

    }
    
    $c->stats->profile("Got viewable sectors");	

    # Make sure all the viewable sectors have a path back to the starting square (i.e. there's no breaks in the viewable area,
    #  avoids the problem of twisting corridors having two lighted sections)
    # TODO: prevent light going round corners (?)
    my $viewable_sectors_by_coord;
    foreach my $viewable_sector (@viewable_sectors) {
        $viewable_sectors_by_coord->[ $viewable_sector->x ][ $viewable_sector->y ] = $viewable_sector;
    }

    my $viewable_sector_grid;

    for my $viewable_sector (@viewable_sectors) {
        if ( $viewable_sector->check_has_path( $current_location, $viewable_sectors_by_coord, 3 ) ) {
            $viewable_sector_grid->[ $viewable_sector->x ][ $viewable_sector->y ] = 1;
        }
    }
    
    $c->stats->profile("Fixed viewable sectors");
    $c->stats->profile(end => "build_viewable_sector_grids");	
    
    return [\@sectors, $viewable_sector_grid, $allowed_to_move_to, $cgs, $parties];		
}

sub render_dungeon_grid : Private {
    my ( $self, $c, $viewable_sectors, $mapped_sectors, $allowed_to_move_to, $current_location, $cgs, $parties ) = @_;

    my @positions = map { $_->position } $c->model('DBIC::Dungeon_Position')->search;

    my $grid;
    my ( $min_x, $min_y, $max_x, $max_y ) = ( $mapped_sectors->[0]->{x}, $mapped_sectors->[0]->{y}, 0, 0 );

    foreach my $sector (@$mapped_sectors) {

        #$c->log->debug( "Rendering: " . $sector->{x} . ", " . $sector->{y} );
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
                    create_tooltips => 1,
                },
                return_output => 1,
            }
        ]
    );
}

sub move_to : Local {
    my ( $self, $c, $sector_id, $no_hash_check ) = @_;

    $sector_id ||= $c->req->param('sector_id');

    my $current_location =
        $c->model('DBIC::Dungeon_Grid')->find( { dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, }, { prefetch => 'dungeon_room', } );

    my $sector = $c->model('DBIC::Dungeon_Grid')->find( { 'dungeon_grid_id' => $sector_id, }, { prefetch => 'dungeon_room', } );

    croak "Can't find sector: $sector_id" unless $sector;

    $c->log->debug( "Attempting to move to " . $sector->x . ", " . $sector->y );

    # Check they're moving to a sector in the dungeon they're currently in
    if ( $current_location->dungeon_room->dungeon_id != $current_location->dungeon_room->dungeon_id ) {
        croak "Can't move to sector: $sector_id - in the wrong dungeon";
    }

	# Check sector is in range. We trust the random 'h' param to tell us so we don't have to do the (slow) check again
    if (0) { #! $no_hash_check && $c->req->param('h') != $c->flash->{allowed_move_hashes}[$sector->x][$sector->y]) {
        $c->stash->{error} = "You must be in range of the sector";
    }
    elsif ( $c->stash->{party}->turns < 1 ) {
        $c->stash->{error} = "You do not have enough turns to move there";
    }
    # Can't move if a character is overencumbered
    elsif ( $c->stash->{party}->has_overencumbered_character ) {
    	$c->stash->{error} = "One or more characters is carrying two much equipment. Your party cannot move"; 
	}   
    
    else {
        $c->forward( 'check_for_creature_move', [$current_location] );

        my $creature_group = $c->forward( '/dungeon/combat/check_for_attack', [$sector] );

        # If creatures attacked, refresh party panel
        if ($creature_group) {
            push @{ $c->stash->{refresh_panels} }, 'party';
        }

        $c->stash->{party}->dungeon_grid_id($sector_id);
        $c->stash->{party}->turns( $c->stash->{party}->turns - 1 );
        $c->stash->{party}->update;
        $c->stash->{party}->discard_changes;
        
        my $sectors = $c->forward('build_updated_sectors_data', [$current_location, $sector_id]);
        
        $c->stash->{panel_callbacks} = [
        	{
        		name => 'dungeon',
        		data => $sectors,
        	}
        ];
    }

    $c->forward( '/panel/refresh', [ 'messages', 'party_status' ] );
}

sub build_updated_sectors_data : Private {
	my ($self, $c, $current_location, $sector_id) = @_;
	
	my $new_location = $c->model('DBIC::Dungeon_Grid')->find($sector_id);
	
	my $grids = $c->forward('build_viewable_sector_grids', [$new_location]);
	my ($orginal_sectors, $viewable_sector_grid, $allowed_to_move_to, $cgs, $parties) = @$grids;
	
	push @$orginal_sectors, $new_location; # Not included in original array 
	
	my $orginal_sectors_grid;
	foreach my $sector (@$orginal_sectors) {
		$orginal_sectors_grid->[$sector->x][$sector->y] = $sector;		
	}
	
	my @positions = map { $_->position } $c->model('DBIC::Dungeon_Position')->search;
	
	my $sectors;
	my $cg_descs;
		
	my ( $top_corner, $bottom_corner ) = RPG::Map->surrounds_by_range( $new_location->x, $new_location->y, 3 );
	for my $y ($top_corner->{y} .. $bottom_corner->{y}) {
		for my $x ($top_corner->{x} .. $bottom_corner->{x}) {	
			my $current_sector = $orginal_sectors_grid->[$x][$y];
			
			next unless $current_sector;

			# Only sectors in allowed_to_move_to or viewable area (or current location) should be updated
			next unless $allowed_to_move_to->{$current_sector->id} || 
				($new_location->x == $x && $new_location->y == $y);
=comment
			# Update dungeon boundaries
			if ($x < $c->session->{mapped_dungeon_boundaries}{min_x}) {
				$c->session->{mapped_dungeon_boundaries}{min_x} = $x;
			}
			elsif ($x > $c->session->{mapped_dungeon_boundaries}{max_x}) {
				$c->session->{mapped_dungeon_boundaries}{max_x} = $x;
			}
			
			if ($y < $c->session->{mapped_dungeon_boundaries}{min_y}) {
				$c->session->{mapped_dungeon_boundaries}{min_y} = $y;
			}
			elsif ($y > $c->session->{mapped_dungeon_boundaries}{y}) {
				$c->session->{mapped_dungeon_boundaries}{max_y} = $y;
			}			
=cut		

			# Check if sector is mapped by party
			# TODO: might be a bit slow?
			unless ($c->model('DBIC::Mapped_Dungeon_Grid')->find(
				{
					dungeon_grid_id => $current_sector->id,
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
		                    max_x               => $c->session->{mapped_dungeon_boundaries}{max_x},
		                    max_y               => $c->session->{mapped_dungeon_boundaries}{max_y},
		                    min_x               => $c->session->{mapped_dungeon_boundaries}{min_x},
		                    min_y               => $c->session->{mapped_dungeon_boundaries}{min_y},		                	
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
            party_id                  => $c->stash->{party}->id,
        },
        {
            join     => [ 'dungeon_room', 'mapped_dungeon_grid' ],
            prefetch => 'treasure_chest',
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
		                },
		                return_output => 1,
		            }
		        ]
    		);			
		}
	}
		
	# TODO: logic duplicated from template, but probably needs to be here. Probably better to pull it out of the template, and
	#  use it from here, rather than the template, as /dungeon/view does
	my $scroll_to = {
		x => $new_location->x + 6,
		y => $new_location->y + 4,
	};
	
	return {
		sectors => $sectors,
		scroll_to => $scroll_to,
		boundaries => $c->session->{mapped_dungeon_boundaries},
	};
	
}

sub check_for_creature_move : Private {
    my ( $self, $c, $current_location ) = @_;

    my @creatures_in_room =
        $c->model('DBIC::CreatureGroup')
        ->search( { 'dungeon_grid.dungeon_room_id' => $current_location->dungeon_room_id, }, { prefetch => 'dungeon_grid', }, );

    my @possible_sectors = shuffle $c->model('DBIC::Dungeon_Grid')->search(
        {
            'dungeon_room_id'                  => $current_location->dungeon_room_id,
            'creature_group.creature_group_id' => undef,
        },
        { join => 'creature_group', }
    );

    foreach my $cg (@creatures_in_room) {
        next if $cg->in_combat_with;

        next if Games::Dice::Advanced->roll('1d100') > $c->config->{creature_move_chance_on_party_move};

        my $sector_to_move_to = shift @possible_sectors;

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
        },
        { join => 'dungeon_room', }
    );

    $c->forward( 'move_to', [ $sector_to_move_to->id, 1 ] );
}

sub sector_menu : Local {
    my ( $self, $c ) = @_;

    my $current_location =
        $c->model('DBIC::Dungeon_Grid')
        ->find( 
        	{ 
        		dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, 
        	}, 
        	{ 
        		prefetch => [
        			{'doors' => 'position'},
        			'treasure_chest',
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

    # Only attempt to unblock door if action matches door's type
    if ( $action_for_door{ $c->req->param('action') } eq $door->type ) {

        my %stats = (
            charge => [ 'strength',     'constitution' ],
            pick   => [ 'agility',      'intelligence' ],
            break  => [ 'intelligence', 'divinity' ],
        );

        my $stats = $stats{ $c->req->param('action') };
        my $stat_avg = average $character->get_column( $stats->[0] ), $character->get_column( $stats->[1] );

        my $roll_base              = 15;
        my $dungeon_level_addition = $current_location->dungeon_room->dungeon->level * 5;
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

    croak "No stairs here" unless $current_location->stairs_up;

    # Reset zoom level
    $c->session->{zoom_level} = 2;

    $c->stash->{party}->dungeon_grid_id(undef);
    $c->stash->{party}->turns( $c->stash->{party}->turns - 1 );
    $c->stash->{party}->update;

    $c->forward( '/panel/refresh', [ 'map', 'messages', 'party_status', 'zoom' ] );
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

# Generates hashes of allowed moves, and saves them in the flash, so we can check only allowed sectors were passed to move_to
# (this is an optimisation)
sub store_allowed_move_hashes : Private {
    my ( $self, $c, $allowed_to_move_to ) = @_;

    my $allowed_hashes;
    foreach my $x ( 0 .. scalar @$allowed_to_move_to ) {
        if ($allowed_to_move_to->[$x]) {
            foreach my $y ( 0 .. scalar @{ $allowed_to_move_to->[$x] } ) {
                if ( $allowed_to_move_to->[$x][$y] ) {
                    $allowed_hashes->[$x][$y] = int rand 100000000;
                }
            }
        }
    }

    $c->flash->{allowed_move_hashes} = $allowed_hashes;
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

	my @items = $current_location->treasure_chest->items;
	
	my @characters = $c->stash->{party}->characters;
	
	my @items_found;
	
	foreach my $item (@items) {
		# XXX: call find_dungeon_item quest hack, see method for details
		if ($c->forward('check_for_quest_item', [$item])) {
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
                },
                return_output => 1,
            }
        ]
    );

    push @{$c->stash->{messages}},  $message;
    
    my $dungeon = $current_location->dungeon_room->dungeon;
    my $quest_messages = $c->forward( '/quest/check_action', [ 'chest_opened', $dungeon->id, \@items ] );
    
    push @{$c->stash->{messages}}, @$quest_messages;

    $c->stash->{party}->turns( $c->stash->{party}->turns - 1 );
    $c->stash->{party}->update;

    $c->forward( '/panel/refresh', [ 'messages', 'party_status' ] );
}

# XXX: this is a hack to get around the problem of parties picking up an item created for an item quest for a particular party
#  If an item has a name, we check if it's involved in a quest, and if the current party is the correct one. If not, the item
#  effectively invisible to this party.
sub check_for_quest_item : Private {
	my ($self, $c, $item) = @_;
	
	return 0 unless $item->name;
	
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
	return 0 if $quest->party_id == $c->stash->{party}->id;
	
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
