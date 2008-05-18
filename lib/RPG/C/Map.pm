package RPG::C::Map;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use JSON;

sub view : Local {
    my ($self, $c) = @_;
    
    $c->stats->profile("Entered /map/view");

	# Fetch from the DB, since it may have changed recently
    my $party_location = $c->model('DBIC::Land')->find(
    	{
    		land_id => $c->stash->{party}->land_id,
    	}
    );
    
	$c->stats->profile("Got party's location");

    my ($start_point, $end_point) = RPG::Map->surrounds(
                                        $party_location->x,
                                        $party_location->y,
                                        $c->config->{map_x_size},
                                        $c->config->{map_y_size},
                                    );
                                    
	$c->stats->profile("Got start and end point");                                    
    
    my @area = $c->model('Land')->search(
        {
            'x' => {'>=', $start_point->{x},'<=', $end_point->{x}},
            'y' => {'>=', $start_point->{y},'<=', $end_point->{y}},
        },
        {
        	prefetch => 'terrain',
        },
    );
    
    $c->stats->profile("Queried db for sectors");
    
    my @grid;
    
    foreach my $location (@area) {
        $grid[$location->x][$location->y] = $location;
    }
    
    $c->stats->profile("Built grid");
    
    return $c->forward('RPG::V::TT',
        [{
            template => 'map/generate_map.html',
            params => {
                grid => \@grid,
                current_position => $party_location,
                party_movement_factor => $c->stash->{party}->movement_factor,
                image_path => RPG->config->{map_image_path},
            },
            return_output => 1,
        }]
    );
    
    $c->stats->profile("Rendered template");
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
	    
    }
    
    $c->forward('/panel/refresh', ['map', 'messages', 'party_status']);
}

1;