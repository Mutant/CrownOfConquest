package RPG::C::Map;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use JSON;
use Carp;

use RPG::Schema::Land;
use RPG::Map;

use DBIx::Class::ResultClass::HashRefInflator;

sub view : Private {
    my ( $self, $c ) = @_;

    my $party_location = $c->stash->{party_location};
    
    $c->session->{zoom_level} ||= 2;
    my $zoom_level = $c->session->{zoom_level};
    
    my $grid_size = $c->config->{map_x_size} + (($zoom_level-2) * 3) + 1;
    $grid_size-- if $c->session->{zoom_level} % 2 == 0;    # Odd numbers cause us problems
    
    my $grid_params =
        $c->forward( 'generate_grid', [ $grid_size, $grid_size, $party_location->x, $party_location->y, 1, ], );

    $grid_params->{click_to_move} = 1;
    $grid_params->{x_size}        = $grid_size;
    $grid_params->{y_size}        = $grid_size;
    $grid_params->{grid_size}     = $grid_size;
    $grid_params->{zoom_level}    = $zoom_level;

    $c->forward( 'render_grid', [ $grid_params, ] );
}

sub party : Local {
    my ( $self, $c ) = @_;

    my @known_towns = $c->model('DBIC::Town')->search(
        { 'mapped_sector.party_id' => $c->stash->{party}->id, },
        {
            prefetch => { 'location' => 'mapped_sector' },
            order_by => 'town_name',
        },
    );

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'map/party.html',
                params   => {
                    known_towns => \@known_towns,
                },
            }
        ]
    );
}

sub party_inner : Local {
    my ( $self, $c ) = @_;   
    
    my $zoom_level = $c->req->param('zoom_level') || $c->session->{zoom_level} || 2;
    $c->session->{zoom_level} = $zoom_level;
    if ( $zoom_level < 2 || $zoom_level > 7 ) {
        $zoom_level = 2;
    }

    my ( $centre_x, $centre_y );

    if ( $c->req->param('center_x') && $c->req->param('center_y') ) {
        ( $centre_x, $centre_y ) = ( $c->req->param('center_x'), $c->req->param('center_y') );
    }
    else {
        my $party_location = $c->stash->{party_location};

        $centre_x = $party_location->x + ( $c->req->param('x_offset') || 0 );
        $centre_y = $party_location->y + ( $c->req->param('y_offset') || 0 );
    }

    my $x_size = $zoom_level * 12 + 1;
    my $y_size = $zoom_level * 9 + 1;
    $x_size-- if $zoom_level % 2 == 1;    # Odd numbers cause us problems
        
    my @coords = RPG::Map->surrounds(
        $centre_x,
        $centre_y,
        $x_size,
        $y_size,
        
    );
    
    my ($top_x, $top_y) = ($coords[0]->{x}, $coords[0]->{y});
    
    $c->log->debug("x_center: $centre_x, y_center: $centre_y; x_top: $top_x; y_top: $top_y; x_size: $x_size; y_size: $y_size;");

    my $grid_params = $c->forward( 'generate_grid', [ $x_size, $y_size, $centre_x, $centre_y, ], );

    $grid_params->{click_to_move} = 0;
    $grid_params->{x_size}        = $x_size;
    $grid_params->{y_size}        = $y_size;
    $grid_params->{zoom_level}    = $zoom_level;
    $grid_params->{grid_size}     = $x_size;

    my $map = $c->forward( 'render_grid', [ $grid_params, ] );    
    
    my $inner = $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'map/party_inner.html',
                params   => {
                    map         => $map,
                    move_amount => 12,
                    zoom_level  => $zoom_level,
                },
                return_output => 1,
            }
        ]
    );
    
    $c->res->body( to_json(
        {
            inner => $inner,
            map_box_coords => {
                'x_size' => int $x_size,
                'y_size' => int $y_size,
                'top_x' => int $top_x,
                'top_y' => int $top_y,
            },
        }
    ));  
}

sub known_dungeons : Local {
    my ( $self, $c ) = @_;

    my $mapped_sectors_rs = $c->model('DBIC::Mapped_Sectors')->search(
        { 
        	'party_id' => $c->stash->{party}->id,
        	'known_dungeon' => {'!=', 0},        	
        },
        {
        	prefetch => 'location',
            order_by => 'known_dungeon, location.x, location.y',
        },
    );
    
    $mapped_sectors_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
    
    my @known_dungeons = $mapped_sectors_rs->all;
    
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'map/known_dungeons.html',
                params   => { known_dungeons => \@known_dungeons, },
            }
        ]
    );

}

sub generate_grid : Private {
    my ( $self, $c, $x_size, $y_size, $x_centre, $y_centre, $add_to_party_map ) = @_;

    $c->stats->profile("Entered /map/view");

    $c->stats->profile("Got party's location");

    my ( $start_point, $end_point ) = RPG::Map->surrounds( $x_centre, $y_centre, $x_size, $y_size, 1 );

    $c->stats->profile("Got start and end point");

    my $locations = $c->model('DBIC::Land')->get_party_grid(
        start_point  => $start_point,
        end_point    => $end_point,
        centre_point => {
            x => $x_centre,
            y => $y_centre,
        },
        party_id => $c->stash->{party}->id,
    );

    $c->stats->profile("Queried db for sectors");
   
    #$c->log->debug("X center: $x_centre; Y Centre: $y_centre");
   
    my @roads = $c->model('DBIC::Road')->find_in_range(
        {
            x => $x_centre,
            y => $y_centre,
        },
        $x_size,
    );    
    
    my $road_grid;
    foreach my $road (@roads) {
        push @{$road_grid->[ $road->{location}->{x} ][ $road->{location}->{y} ]}, $road;
    }

	#  Add any buildings
    my @buildings = $c->model('DBIC::Building')->find_in_range(
        {
            x => $x_centre,
            y => $y_centre,
        },
        $x_size,
    );    
    
    my $building_grid;
    foreach my $building (@buildings) {
        push @{$building_grid->[ $building->{location}->{x} ][ $building->{location}->{y} ]}, $building;
    }
   
    $c->stats->profile("Queried db for roads");

    my @grid;

    my $movement_factor = $c->stash->{party}->movement_factor;

    foreach my $location (@$locations) {
        $location->{roads} = $road_grid->[ $location->{x} ][ $location->{y} ];
        $location->{buildings} = $building_grid->[ $location->{x} ][ $location->{y} ];
        
        $grid[ $location->{x} ][ $location->{y} ] = $location;

        if ($location->{next_to_centre}) {
            $location->{party_movement_factor} = RPG::Schema::Land::movement_cost( $location, $movement_factor, $location->{modifier}, $c->stash->{party_location} );
        }
        else {
            $location->{party_movement_factor} = RPG::Schema::Land->movement_cost( $movement_factor, $location->{modifier}, );
        }

        # Record sector to the party's map
        if ( $add_to_party_map && !$location->{mapped_sector_id} ) {
        	# Only record if they're within the 'viewing range'
        	my $distance = RPG::Map->get_distance_between_points(
        		{
        			x => $x_centre,
        			y => $y_centre,
        		},
        		{
        			x => $location->{x},
        			y => $location->{y},
        		},
        	);
        	
        	if ($distance <= $c->config->{party_viewing_range}) {
	            $c->model('DBIC::Mapped_Sectors')->create(
	                {
	                    party_id => $c->stash->{party}->id,
	                    land_id  => $location->{land_id},
	                },
	            );
        	}
        	else {
        		# Remove it from the grid, as they haven't got it in their map, and it's too far away to see it
        		$grid[ $location->{x} ][ $location->{y} ] = "";
        	}
        }
        elsif ( !$add_to_party_map && !$location->{mapped_sector_id} ) {
            $grid[ $location->{x} ][ $location->{y} ] = "";
        }
    }

    $c->stats->profile("Built grid");

    return {
        grid        => \@grid,
        start_point => $start_point,
        end_point   => $end_point,
    };
}

# Render a map grid
# Params in hash:
#  * grid: grid of the map sectors to render
#  * start_point: hash of x & y location for start (i.e. top left) of the map
#  * end_point: hash of x & y location for end (i.e. bottom right) of the map

sub render_grid : Private {
    my ( $self, $c, $params ) = @_;

    $params->{x_range}          = [ $params->{start_point}{x} .. $params->{end_point}{x} ];
    $params->{y_range}          = [ $params->{start_point}{y} .. $params->{end_point}{y} ];
    $params->{image_path}       = RPG->config->{map_image_path};
    $params->{current_position} = $c->stash->{party_location};
    $params->{party_in_combat}  = $c->stash->{party}->in_combat;
    $params->{min_x}            = $params->{start_point}{x};
    $params->{min_y}            = $params->{start_point}{y};
    $params->{zoom_level} ||= 2;
    $params->{party} = $c->stash->{party};

    # Find any towns and calculate their tax costs
    my %town_costs;
    foreach my $row ( @{ $params->{grid} } ) {
        foreach my $sector (@$row) {
            next unless $sector;
            if ( $sector->{town_id} ) {
                my $town = $c->model('DBIC::Town')->find( { town_id => $sector->{town_id} } );

                $town_costs{ $sector->{town_id} } = $town->tax_cost( $c->stash->{party} );
            }
        }
    }

    $params->{town_costs} = \%town_costs;

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template      => 'map/generate_map.html',
                params        => $params,
                return_output => 1,
            }
        ]
    );
}

=head2 move_to

Move the party to a new location

=cut

sub move_to : Local {
    my ( $self, $c ) = @_;

    my $new_land = $c->model('DBIC::Land')->find( $c->req->param('land_id'), { prefetch => [ 'terrain', 'town' ] }, );

    unless ($new_land) {
        $c->error('Land does not exist!');
    }
    # If there's a town, check that they've gone in via /town/enter
    elsif ( $new_land->town && !$c->stash->{entered_town} ) {
        croak 'Invalid town entrance';
    }
    elsif ($c->stash->{entered_town} || $c->forward('can_move_to_sector', [$new_land])) {   	
        #$c->log->debug("Before p move_to: " . $c->stash->{party}->land_id);
        
        $c->stash->{party}->move_to($new_land);

        $c->stash->{party}->update;

        # Fetch from the DB, since it may have changed recently
        #$c->log->debug("After p move_to: " . $c->stash->{party}->land_id);
        $c->stash->{party_location} = $c->model('DBIC::Land')->find( { land_id => $c->stash->{party}->land_id, } );

        $c->stash->{party_location}->creature_threat( $c->stash->{party_location}->creature_threat - 1 );
        $c->stash->{party_location}->update;

        my $mapped_sector = $c->model('DBIC::Mapped_Sectors')->find_or_create(
            {
                party_id => $c->stash->{party}->id,
                land_id  => $new_land->id,
            },
            {
            	prefetch => { location => 'dungeon' },
            },
        );
        
        my $has_dungeon = $mapped_sector->location->dungeon && $mapped_sector->location->dungeon->type eq 'dungeon' ? 1 : 0;
        
        if ($mapped_sector) {
        	if ($mapped_sector->known_dungeon && ! $has_dungeon) {
            	# They thought there was a dungeon here, but there's not
            	$mapped_sector->update( { known_dungeon => 0 } );
            
            	$c->stash->{had_phantom_dungeon} = 1;
        	}
        	elsif ($has_dungeon) {
        		# They in a sector with a dungeon - add it to known dungeons if they're high enough level
        		my $dungeon = $mapped_sector->location->dungeon;
        		
        		if ($dungeon->party_can_enter($c->stash->{party})) {
        			$mapped_sector->known_dungeon( $dungeon->level );
        			$mapped_sector->update;
        		}
        	}
        }
        
        $c->stash->{mapped_sector} = $mapped_sector;

		my $already_messaged_garrison = -1;
        if (my $garrison = $new_land->garrison) {
        	# Garrison records a party sighting (unless it's the owner)
        	if ($garrison->party_id != $c->stash->{party}->id) {
        		$c->model('DBIC::Garrison_Messages')->create(
        			{
        				garrison_id => $garrison->id,
        				day_id => $c->stash->{today}->id,
        				message => 'The party known as ' . $c->stash->{party}->name . ' passed through our sector',
        			}
        		);
        		$already_messaged_garrison = $garrison->id;
        	}
        }
        
        my @nearby_garrisoned_blds = $self->find_nearby_garrisoned_buildings($c,
         $c->stash->{party_location}->x, $c->stash->{party_location}->y);
        foreach my $finfo (@nearby_garrisoned_blds) {
        	if ($finfo->{garrison}->{garrison_id} != $already_messaged_garrison) {

        		$c->model('DBIC::Garrison_Messages')->create(
        			{
        				garrison_id => $finfo->{garrison}->{garrison_id},
        				day_id => $c->stash->{today}->id,
        				message => 'From our ' . $finfo->{building}->{building_type}->{name} . ', we spotted the party known as ' .
        				 $c->stash->{party}->name . ' in the distance at sector (' .
        				 $c->stash->{party_location}->x . "," . $c->stash->{party_location}->y . ")",
        			}
        		);
        	}
        }

        my $creature_group = $c->forward( '/combat/check_for_attack', [$new_land] );

        # If creatures attacked, refresh party panel
        if ($creature_group) {
            push @{ $c->stash->{refresh_panels} }, 'party';
        }

    }
    
    #$c->log->debug("ploc x: " . $c->stash->{party_location}->x . ", ploc y: " . $c->stash->{party_location}->y);

    $c->forward( '/panel/refresh', [ 'map', 'messages', 'party_status' ] );
}

#  find_nearby_garrisoned_buildings - returns an array given information on nearby garrisoned buildings within the range
#    of the given sector coordinate.  Returns an array of hashes, each which has a 'garrison' and 'building' entry that
#    contains the resultsset info for that garrison/building.
sub find_nearby_garrisoned_buildings {
	my ( $self, $c, $x_centre, $y_centre ) = @_;

	my $max_range = $c->config->{max_building_visibility};
    my @garrisons = $c->model('DBIC::Garrison')->find_in_range(
        {
            x => $x_centre,
            y => $y_centre,
        },
        $max_range,
    );

	#  If there are no garrisons in range, then there aren't any garrisoned buildings.
	my @found;
	if (@garrisons == 0) {
		return @found;
	}
	
    my @buildings = $c->model('DBIC::Building')->find_in_range(
        {
            x => $x_centre,
            y => $y_centre,
        },
        $max_range,
    ); 	

	#  Build a hash of garrison/building keyed by location name (x.y)
	my %locations;
    foreach my $garrison (@garrisons) {
    	my $locName = "" . $garrison->{land}->{x} . "." . $garrison->{land}->{y};
    	$locations{$locName}{garrison} = $garrison;
    }

    foreach my $building (@buildings) {
    	my $locName = "" . $building->{location}->{x} . "." . $building->{location}->{y};
    	$locations{$locName}{building} = $building;
    }

	#  Traverse all the locations that had a garrison or a building.
    foreach my $loc (keys %locations) {
    	my $locInfo = $locations{$loc};

    	#  If the location has both a garrison and building, check it.
    	if (defined $locInfo->{garrison} && defined $locInfo->{building}) {

    		#  Is the party not us, and does the garrison own the building (it should).
  			if ($locInfo->{garrison}->{party_id} != $c->stash->{party}->id ) {
		 	
  			 	#  Finally, is our party in range (i.e. can the 'see' us?)
  			 	my $dist = RPG::Map->get_distance_between_points(
  			 		{x => $x_centre, y => $y_centre},
  			 		{x => $locInfo->{building}->{location}->{x}, y => $locInfo->{building}->{location}->{y}}
  			 	);
  			 	if ($dist <= $locInfo->{building}->{building_type}->{visibility}) {
  			 		push @found, {garrison => $locInfo->{garrison}, building => $locInfo->{building}};
  			 	}
  			}
    	}
    }
    return @found;
}


# Check if a sector can be moved to
sub can_move_to_sector : Private {
	my ( $self, $c, $new_land ) = @_;
	
	my $movement_factor = $c->stash->{party}->movement_factor;
	
    # Check that the new location is actually next to current position.
    if ( !$c->stash->{party}->location->next_to($new_land) ) {
        $c->stash->{error} = 'You can only move to a location next to your current one';
        return 0;
    }
    
    # Check that the party has enough movement points
    elsif ( $c->stash->{party}->turns < $new_land->movement_cost($movement_factor, undef, $c->stash->{party}->location) ) {
        $c->stash->{error} = 'You do not have enough turns to move there';
        return 0;
    }
  
    # Can't move if a character is overencumbered
    elsif ( $c->stash->{party}->has_overencumbered_character ) {
    	$c->stash->{error} = "One or more characters is carrying two much equipment. Your party cannot move";
    	return 0; 
	}	
	
	return 1;
}

sub kingdom : Local {
    my ($self, $c) = @_;
    
    my $land_rs = $c->model('DBIC::Land')->search(
        {},
        {
            prefetch => 'kingdom',
            order_by => ['y','x'],
        }
    );
    
    $Template::Directive::WHILE_MAX = 100000;
    

    
    $land_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
    
    return $c->forward(
        'RPG::V::TT',
        [
            {
                template      => 'map/kingdom_map.html',
                params        => {
                    land_rs => $land_rs,               
                },
            }
        ]
    );    
}

1;
