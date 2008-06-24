package RPG::C::Map;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use JSON;
use DBIx::Class::ResultClass::HashRefInflator;

sub view : Local {
    my ($self, $c) = @_;
    
    my $party_location = $c->stash->{party_location};
    
    my $grid_params = $c->forward('generate_grid',
    	[
			$c->config->{map_x_size},
			$c->config->{map_y_size},
			$party_location->x,
			$party_location->y,
			1,
		],
	);
	
	$grid_params->{click_to_move} = 1;
	
	return $c->forward('render_grid',
		[
			$grid_params,
		]
	);
}

sub party : Local {
	my ($self, $c) = @_;
	
	my ($centre_x, $centre_y);
	
	if ($c->req->param('center_x') && $c->req->param('center_y')) {
		($centre_x, $centre_y) = ($c->req->param('center_x'), $c->req->param('center_y'));
	}
	else {		 
	    my $party_location = $c->stash->{party_location};
	    
	    $centre_x = $party_location->x + $c->req->param('x_offset');
	    $centre_y = $party_location->y + $c->req->param('y_offset');
	}
    
	my $grid_params = $c->forward('generate_grid',
		[
			25,
	        25,
	        $centre_x,
	        $centre_y,
	    ],
	);
	
	$grid_params->{click_to_move} = 0;
	
	my $map = $c->forward('render_grid',
		[
			$grid_params,
		]
	);
	
	$c->forward('RPG::V::TT',
        [{
            template => 'map/party.html',
            params => {
                map => $map,
                move_amount => 12,                
               
            },
        }]
    );
}

sub generate_grid : Private {
    my ($self, $c, $x_size, $y_size, $x_centre, $y_centre, $add_to_party_map) = @_;
    
    $c->stats->profile("Entered /map/view");
    
	$c->stats->profile("Got party's location");

    my ($start_point, $end_point) = RPG::Map->surrounds(
    	$x_centre,
    	$y_centre,
    	$x_size,
    	$y_size,
	);
                                    
	$c->stats->profile("Got start and end point");       
	
	# TODO: move into model
    my $search_rs = $c->model('Land')->search(
        {
            'x' => {'>=', $start_point->{x},'<=', $end_point->{x}},
            'y' => {'>=', $start_point->{y},'<=', $end_point->{y}},
            'party_id' => [$c->stash->{party}->id, undef],
        },
        {
        	prefetch => ['terrain', 'mapped_sector', 'town'],
        	'+select' => [{ '' => '(x >= ' . ($x_centre-1) . ' and x <= ' . ($x_centre+1) . 
        				 ') and (y >= ' . ($y_centre-1) . ' and y <= ' . ($y_centre+1) .
        				 ") and (y!=$y_centre or x!=$x_centre)"}],
        	'+as' => ['next_to_centre'],
        },
    );
    
	$search_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
        
    $c->stats->profile("Queried db for sectors");
    
    my @grid;    
        
    while (my $location = $search_rs->next) {
        $grid[$location->{x}][$location->{y}] = $location;
        
        $location->{party_movement_factor} = $c->stash->{party}->movement_factor + $location->{terrain}{modifier};
        
        # Record sector to the party's map
        if ($add_to_party_map && ! $location->{mapped_sector}) {
        	$c->model('DBIC::Mapped_Sectors')->create(
	        	{
		    	    party_id => $c->stash->{party}->id,
			       	land_id  => $location->{land_id},
		    	},
       		);
        }
        elsif (! $add_to_party_map && ! $location->{mapped_sector}) {
        	$grid[$location->{x}][$location->{y}] = "";
        }
    }
    
    $c->stats->profile("Built grid");
    
    return {
    	grid => \@grid,
    	start_point => $start_point,
    	end_point => $end_point,
    };
}
    
# Render a map grid
# Params in hash:
#  * grid: grid of the map sectors to render
#  * start_point: hash of x & y location for start (i.e. top left) of the map
#  * end_point: hash of x & y location for end (i.e. bottom right) of the map

sub render_grid : Private {
	my ($self, $c, $params) = @_;
	
	$params->{x_range} = [$params->{start_point}{x} .. $params->{end_point}{x}];
	$params->{y_range} = [$params->{start_point}{y} .. $params->{end_point}{y}];
	$params->{image_path} = RPG->config->{map_image_path};
	$params->{current_position} = $c->stash->{party_location};
    
    return $c->forward('RPG::V::TT',
        [{
            template => 'map/generate_map.html',
            params => $params,
            return_output => 1,
        }]
    );    
}

=head2 move_to

Move the party to a new location

=cut

sub move_to : Local {
    my ($self, $c) = @_;
    
    #my $party = $c->stash->{party};
    
    my $new_land = $c->model('Land')->find( 
    	$c->req->param('land_id'),
    	{
    		prefetch => 'terrain',
    	},
    );

    my $movement_factor = $c->stash->{party}->movement_factor;
        
    unless ($new_land) {
        $c->error('Land does not exist!');
    }
    
    # Check that the new location is actually next to current position.
    elsif (! $c->stash->{party}->location->next_to($new_land)) {
        $c->stash->{error} = 'You can only move to a location next to your current one';
    }    
    
    # Check that the party has enough movement points
    elsif ($c->stash->{party}->turns < $new_land->movement_cost($movement_factor)) {
        $c->stash->{error} = 'You do not have enough movement points to move there';
    }
    
    else {        
	    $c->stash->{party}->land_id($c->req->param('land_id'));
	    $c->stash->{party}->turns($c->stash->{party}->turns - $new_land->movement_cost($movement_factor));
	    
		# See if party is in same location as a creature
	    my $creature_group = $c->model('DBIC::CreatureGroup')->find(
	        {
	            'location.x' => $new_land->x,
	            'location.y' => $new_land->y,
	        },
	        {
	            prefetch => [('location', {'creatures' => 'type'})],
	        },
	    );		    
		    
	    # If there are creatures here, check to see if we go straight into a combat
	    if ($creature_group) {
	    	$c->stash->{creature_group} = $creature_group;
	    		    	
	    	if ($creature_group->initiate_combat($c->stash->{party}, $c->config->{creature_attack_chance})) {
	        	$c->stash->{party}->in_combat_with($creature_group->id);
	    	}
    	}	
	    
	    $c->stash->{party}->update;
	    
	    $c->stash->{party_location}->creature_threat($c->stash->{party_location}->creature_threat - 1);
	    $c->stash->{party_location}->update;
	    
	    # Fetch from the DB, since it may have changed recently
	    $c->stash->{party_location} = $c->model('DBIC::Land')->find(
	    	{
	    		land_id => $c->stash->{party}->land_id,
	    	}
	    );	    
	    
    }
    
    $c->forward('/panel/refresh', ['map', 'messages', 'party_status']);
}

1;