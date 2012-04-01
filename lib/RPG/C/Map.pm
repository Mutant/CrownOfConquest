package RPG::C::Map;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use JSON;
use Carp;
use Math::Round qw(round);
use File::Slurp qw(read_file);

use RPG::Schema::Land;
use RPG::Map;

use DBIx::Class::ResultClass::HashRefInflator;

sub auto : Private {
   my ( $self, $c ) = @_;
   
   unless ($c->session->{map_dimensions}) {
        my %dimensions = $c->model('DBIC::Land')->get_x_y_range;
        $c->session->{map_dimensions} = \%dimensions;
   }
   
   return 1; 
}

sub search : Local {
    my ( $self, $c ) = @_;
    
    my $loc = $c->model('DBIC::Land')->find(
        {
            x => $c->req->param('x'),
            y => $c->req->param('y'),
        }
    );
    
    croak "Location not found" unless $loc; 
    
    my $map = $c->forward('view', [$loc]);
        
    push @{ $c->stash->{refresh_panels} }, [ 'map', $map ];
    
    $c->forward('/panel/refresh');
} 

sub center : Local {
    my ( $self, $c ) = @_;
    
    $c->stash->{refresh_panels} = ['map'];
    
    $c->forward('/panel/refresh');    
}

sub view : Private {
    my ( $self, $c, $loc ) = @_;

    if (ref $loc ne 'RPG::Model::DBIC::Land') {
        # Happens with weird forwarding magic
        undef $loc;
    }
   
    my $party_loc = 0;
    
    if (! $loc) {
        $loc = $c->stash->{party_location};
        
        $c->stash->{party}->discover_sectors($loc);
        
        $party_loc = 1;
        
    }
    
    $c->session->{zoom_level} ||= 2;
    my $zoom_level = $c->session->{zoom_level};
    
    my ($x_grid_size, $y_grid_size) = $self->grid_sizes($c);
    
    my $grid_params =
        $c->forward( 'generate_grid', [ $x_grid_size, $y_grid_size, $loc->x, $loc->y, ], );

    $grid_params->{click_to_move} = 1;
    $grid_params->{x_size}        = $x_grid_size;
    $grid_params->{y_size}        = $y_grid_size;
    $grid_params->{grid_size}     = $x_grid_size;
    $grid_params->{zoom_level}    = $zoom_level;
    $grid_params->{clickable}      = $party_loc ? 1 : 0;
    
    $c->forward('set_map_box_coords', [$loc]);

    return $c->forward( 'render_grid', [ $grid_params, ] );
}

sub grid_sizes {
    my ($self, $c) = @_;
    
    my $zoom_level = $c->session->{zoom_level} // 2;
    
    my $x_grid_size = $c->config->{map_width}{$c->session->{screen_width} // 'small'} + (($zoom_level-2) * 3) + 1;
    $x_grid_size-- if $zoom_level % 2 == 0;    # Odd numbers cause us problems
    my $y_grid_size = $c->config->{map_height}{$c->session->{screen_height} // 'small'} + (($zoom_level-2) * 3) + 1;
    $y_grid_size-- if $zoom_level % 2 == 0;    # Odd numbers cause us problems
    
    return ($x_grid_size, $y_grid_size);       
}

sub landmarks : Local {
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
                template => 'map/landmarks.html',
                params   => {
                    known_towns => \@known_towns,
                },
            }
        ]
    );
}

sub set_map_box_coords : Private {
    my ( $self, $c, $loc ) = @_;  
    
    my $zoom_level = $c->req->param('zoom_level') || $c->session->{zoom_level} || 2;
    
    my $x_size = $zoom_level * 12 + 1;
    my $y_size = $zoom_level * 9 + 1;
    $x_size-- if $zoom_level % 2 == 1;    # Odd numbers cause us problems
        
    my @coords = RPG::Map->surrounds(
        $loc->x,
        $loc->y,
        $x_size,
        $y_size,        
    );    
    
    my ($top_x, $top_y) = ($coords[0]->{x}, $coords[0]->{y});
    
    push @{$c->stash->{panel_callbacks}},
	{
    	name => 'setMapBox',
    	data => {
            'x_size' => int $x_size,
            'y_size' => int $y_size,
            'top_x' => int $top_x,
            'top_y' => int $top_y,
        },
	};
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
    my ( $self, $c, $x_size, $y_size, $x_centre, $y_centre ) = @_;
    
    confess "Invalid call to generate_grid(): $x_size, $y_size, $x_centre, $y_centre"
        unless $x_size && $y_size && $x_centre && $y_centre;

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

    my @roads = $c->model('DBIC::Road')->find_in_range(
        {
            x => $x_centre,
            y => $y_centre,
        },
        {
            x => $x_size,
            y => $y_size,
        },
    );    
    
    my $road_grid;
    foreach my $road (@roads) {
        push @{$road_grid->[ $road->{location}->{x} ][ $road->{location}->{y} ]}, $road;
    }
    
    $c->stats->profile("Queried db for roads");

	#  Add any buildings
    my @buildings = $c->model('DBIC::Building')->find_in_range(
        {
            x => $x_centre,
            y => $y_centre,
        },
        {
            x => $x_size,
            y => $y_size,
        },
    );    
    
    my $building_grid;
    foreach my $building (@buildings) {
        push @{$building_grid->[ $building->{location}->{x} ][ $building->{location}->{y} ]}, $building;
    }
   
    $c->stats->profile("Queried db for buildings");
    
	#  Add garrisons owned by party
    my @garrisons = $c->model('DBIC::Garrison')->find_in_range(
        {
            x => $x_centre,
            y => $y_centre,
        },
        {
            x => $x_size,
            y => $y_size,
        },
        $c->stash->{party}->id,
    );    
    
    my $garrison_grid;
    foreach my $garrison (@garrisons) {
        push @{$garrison_grid->[ $garrison->{land}->{x} ][ $garrison->{land}->{y} ]}, $garrison;
    }
   
    $c->stats->profile("Queried db for garrisons");    

    my @grid;
    my %town_costs;

    my $movement_factor = $c->stash->{party}->movement_factor;

    foreach my $location (@$locations) {
        $location->{roads} = $road_grid->[ $location->{x} ][ $location->{y} ];
        $location->{buildings} = $building_grid->[ $location->{x} ][ $location->{y} ];
        $location->{garrison} = $garrison_grid->[ $location->{x} ][ $location->{y} ];
        
        $grid[ $location->{x} ][ $location->{y} ] = $location;
        
        my $has_roads = defined $road_grid->[ $location->{x} ][ $location->{y} ] ? 1 : 0;

        $location->{party_movement_factor} = RPG::Schema::Land::movement_cost( $location, $movement_factor, $location->{modifier}, $has_roads );

        # Find any towns and calculate their tax costs        
        if ( $location->{town_id} ) {
            my $town = $c->model('DBIC::Town')->find( { town_id => $location->{town_id} } );

            $town_costs{ $location->{town_id} } = $town->tax_cost( $c->stash->{party} );
        }        
    }

    $c->stats->profile("Built grid");

    return {
        grid        => \@grid,
        start_point => $start_point,
        end_point   => $end_point,
        town_costs => \%town_costs,
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
    my ( $self, $c, $params ) = @_;

    my $new_land = $c->model('DBIC::Land')->find( $c->req->param('land_id'), { prefetch => [ 'terrain', 'town' ] }, );
    
    if ($c->stash->{party}->in_combat) {
        croak "Can't move while in combat";   
    }

    unless ($new_land) {
        $c->error('Land does not exist!');
    }
    # If there's a town, check that they've gone in via /town/enter
    elsif ( $new_land->town && !$c->stash->{entered_town} ) {
        croak 'Invalid town entrance';
    }
    elsif ($c->stash->{entered_town} || $c->forward('can_move_to_sector', [$new_land])) {   	
        my @discovered = $c->stash->{party}->move_to($new_land);
        $c->stash->{party}->update;
        push @{ $c->session->{discovered} }, \@discovered;
        $c->stats->profile("Moved party");
        
       
        my $old_sector = $c->stash->{party_location};

        # Fetch from the DB, since it may have changed recently
        $c->stash->{party_location} = $c->model('DBIC::Land')->find( { land_id => $c->stash->{party}->land_id, } );

        $c->stash->{party_location}->creature_threat( $c->stash->{party_location}->creature_threat - 1 );
        $c->stash->{party_location}->update;

        $c->stats->profile("Update party_location");

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
            	$params->{refresh_current} = 1;
        	}
        	elsif ($has_dungeon) {
        		# They in a sector with a dungeon - add it to known dungeons if they're high enough level
        		my $dungeon = $mapped_sector->location->dungeon;
        		
        		if ($mapped_sector->known_dungeon != $dungeon->level && $dungeon->party_can_enter($c->stash->{party})) {
        			$mapped_sector->known_dungeon( $dungeon->level );
        			$mapped_sector->update;
        			
        			# Force sector to reload (so dungeon image gets displayed)
        			$params->{refresh_current} = 1;
        		}
        	}
        }
        
        $c->stash->{mapped_sector} = $mapped_sector;

        $c->stats->profile("Checked for dungeons");

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
        	
        	if ($garrison->check_for_fight($c->stash->{party})) {
        	    $c->stash->{party}->initiate_combat($garrison);
                push @{ $c->stash->{refresh_panels} }, 'party';
                $c->stash->{garrison_initiated} = 1;
        	}         	
        }
        
        
        my @nearby_garrisoned_blds = $self->find_nearby_garrisoned_buildings($c, $c->stash->{party_location}->x, $c->stash->{party_location}->y);
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
        
        $c->stats->profile("Garrison messages");

        my $creature_group = $c->forward( '/combat/check_for_attack', [$new_land] );

        # If creatures attacked, refresh party panel
        if ($creature_group) {
            push @{ $c->stash->{refresh_panels} }, 'party';
        }
        
        $c->stats->profile("Checked for attack");
        
        my ($x_grid_size, $y_grid_size) = $self->grid_sizes($c);
        
        push @{$c->stash->{panel_callbacks}},
    	{
        	name => 'shiftMap',
        	data => {
        	    'xShift' => $new_land->x - $old_sector->x,
        	    'yShift' => $new_land->y - $old_sector->y,
        	    'newSector' => {
        	        x => $new_land->x,
        	        y => $new_land->y,
        	    },
        	    'xGridSize' => $x_grid_size,
        	    'yGridSize' => $y_grid_size,
        	    'mapDimensions' => $c->session->{map_dimensions},
        	},
    	};
        
        push @{ $c->session->{discovered} }, [$new_land->x.','.$new_land->y] if $params->{refresh_current};
        
        $c->stats->profile("Created callback");
        
        $c->forward('set_map_box_coords', [$new_land]);
    }
    
    $c->forward( '/panel/refresh', [ 'messages', 'party_status', 'creatures' ] );
    
    $c->stats->profile("Done");
}

sub generate_sectors {
    my ( $self, $c, $sectors_passed ) = @_;
    
    my @results;
    
    my @lines;
    for my $type (qw/row column/) {
        push @lines, [$c->req->param($type)] if $c->req->param($type);
    }            
    
    if ($c->session->{discovered}) {
        foreach my $discovered_sectors ( @{ $c->session->{discovered} } ) {
            my @disc_lines = RPG::Map->compile_rows_and_columns(@$discovered_sectors);

            next unless @disc_lines;

            push @lines, @disc_lines;            
        }        
    }
    $c->session->{discovered} = undef;
    
    push @lines, @{ $sectors_passed } if $sectors_passed;
    
    foreach my $line (@lines) {       
        # We have a list of sectors that have been added to the map
        #  (as strings, separated by a comma, i.e. "x,y"). We need to 
        #  turn these into something that can be used by generate_grid
        #  (which expects an x & y size and a base point).
        # (Would be easier if generate grid accepted params in a different way, but that would
        #  involve a lot of refactoring)
       
        my @sectors = sort { 
            my ($x1, $y1) = split /,/, $a;
            my ($x2, $y2) = split /,/, $b;
            
            $x1 <=> $x2 || $y1 <=> $y2;
        } @$line;
        
        #warn Dumper \@sectors;
                        
        my ($min_x, $min_y, $max_x, $max_y);
        
        foreach my $sector (@sectors) {
            my ($x,$y) = split /,/, $sector;
            if (! defined $min_x || $x < $min_x) {
                $min_x = $x;
            }
            if (! defined $max_x || $x > $max_x) {
                $max_x = $x;
            }
            if (! defined $min_y || $y < $min_y) {
                $min_y = $y;
            }
            if (! defined $max_y || $y > $max_y) {
                $max_y = $y;
            }
        }
        
        my $mid_point = round(scalar @sectors / 2);

        my ($base_x, $base_y) = split /,/, $sectors[$mid_point-1];
        
        my $x_size = $max_x - $min_x + 1;
        my $y_size = $max_y - $min_y + 1;
        $x_size++ if $x_size % 2 == 0;
        $y_size++ if $y_size % 2 == 0;
        
        my $grid_params = $c->forward( 'generate_grid', [ $x_size, $y_size, $base_x, $base_y, ], );
       
        # Generate the contents of the sector
        for my $x ( $grid_params->{start_point}{x} .. $grid_params->{end_point}{x} ) {
            for my $y ($grid_params->{start_point}{y} .. $grid_params->{end_point}{y} ) {
                                
                my $location = $grid_params->{grid}[$x][$y];
                
                next unless $location;
                                
                my $data = $c->forward(
                    'RPG::V::TT',
                    [
                        {
                            template      => 'map/single_sector.html',
                            params        => {
                                position => $location,
                                click_to_move => 1,
                                x => $x,
                                y => $y,
                                zoom_level => $c->session->{zoom_level},
                                image_path => RPG->config->{map_image_path},
                                town_costs => $grid_params->{town_costs},
                                party => $c->stash->{party},
                            },
                            return_output => 1,
                        }
                    ]
                );
                
                push @results, {
                    sector => "$x,$y",
                    data => $data,
                    parse => $location->{town_id} ? 1 : 0,
                };
            }
        }
        
    }
    
    my %res = (
        loc => {
            x => $c->stash->{party_location}->x,
            y => $c->stash->{party_location}->y,
        },
        sector_data => \@results,
    );
    
    return %res;
    
}

sub load_sectors : Local {
    my ($self, $c) = @_;
    
    my %res = $self->generate_sectors($c);
    
    my $res = to_json(\%res);
    
    $c->res->body($res);
}

sub refresh_current_loc : Private {
    my ($self, $c) = @_;
    
    my $loc = $c->stash->{party_location};
    
    my %res = $self->generate_sectors($c, [[$loc->x . ',' . $loc->y]]);
    
    push @{$c->stash->{panel_callbacks}},
    	{
        	name => 'refreshSector',
        	data => \%res, 
        };
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
    my $movement_cost = $new_land->movement_cost($movement_factor, undef, $c->stash->{party}->location);
    if ( $c->stash->{party}->turns < $movement_cost ) {
        $c->stash->{error} = 'You do not have enough turns to move there';
        return 0;
    }
  
    # Can't move if a character is overencumbered
    if ( $c->stash->{party}->has_overencumbered_character ) {
    	$c->stash->{error} = "One or more characters is carrying two much equipment. Your party cannot move";
    	return 0; 
	}
	
	$c->stash->{movement_cost} = $movement_cost;	
	
	return 1;
}

sub kingdom : Local {
    my ($self, $c) = @_;
    
    push @{$c->stash->{panel_callbacks}},
    	{
        	name => 'miniMapInit',
        	data => { },
    	};    
    
    return $c->forward(
        'RPG::V::TT',
        [
            {
                template      => 'map/kingdom_map.html',
                params        => {
                    mini_map_state => $c->session->{mini_map_state} // 'open',
                },
                return_output => 1,
            }
        ]
    );
}

sub kingdom_data : Local {
    my ($self, $c) = @_;
    
    my $data = read_file($c->config->{data_file_path} . 'kingdoms.json');
    
    $c->res->body($data);  
}

sub change_mini_map_state : Local {
    my ($self, $c) = @_;
    
    $c->session->{mini_map_state} = $c->req->param('state');    
}

1;
