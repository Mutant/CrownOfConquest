package RPG::C::Map;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use JSON;

sub view : Local {
    my ($self, $c) = @_;
    
    my $party_location = $c->stash->{party_location};
    
    return $c->forward('render',
    	[
			$c->config->{map_x_size},
			$c->config->{map_y_size},
			$party_location->x,
			$party_location->y,
			1,
		],
	);
}

sub render : Private {
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
    
    my @area = $c->model('Land')->search(
        {
            'x' => {'>=', $start_point->{x},'<=', $end_point->{x}},
            'y' => {'>=', $start_point->{y},'<=', $end_point->{y}},
            'party_id' => [$c->stash->{party}->id, undef],
        },
        {
        	prefetch => ['terrain', 'mapped_sector'],
        },
    );
    
    $c->stats->profile("Queried db for sectors");
    
    my @grid;    
        
    foreach my $location (@area) {
        $grid[$location->x][$location->y] = $location;
        
        # Record sector to the party's map
        if ($add_to_party_map && ! $location->mapped_sector) {
        	$c->model('DBIC::Mapped_Sectors')->create(
	        	{
		    	    party_id => $c->stash->{party}->id,
			       	land_id  => $location->id,
		    	},
       		);
        }
        elsif (! $add_to_party_map && ! $location->mapped_sector) {
        	$grid[$location->x][$location->y] = "";
        }
    }
    
    $c->stats->profile("Built grid");
    
    return $c->forward('RPG::V::TT',
        [{
            template => 'map/generate_map.html',
            params => {
                grid => \@grid,
                current_position => $c->stash->{party_location},
                party_movement_factor => $c->stash->{party}->movement_factor,
                image_path => RPG->config->{map_image_path},
                x_range => [$start_point->{x} .. $end_point->{x}],
                y_range => [$start_point->{y} .. $end_point->{y}],
            },
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

sub party : Local {
	my ($self, $c) = @_;
	
    my $party_location = $c->stash->{party_location};
    
	my $map = $c->forward('render',
		[
			25,
	        25,
			$party_location->x,
	        $party_location->y,
	    ],
	);
	
	$c->forward('RPG::V::TT',
        [{
            template => 'map/party.html',
            params => {
                map => $map,
            },
        }]
    );
}

1;