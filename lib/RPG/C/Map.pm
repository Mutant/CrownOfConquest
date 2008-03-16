package RPG::C::Map;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;

sub view : Local {
    my ($self, $c) = @_;
    
    #$c->stats->profile("Entered /map/view");
    $c->forward('auto') unless $c->stash->{party};
    my $party_location = $c->stash->{party}->location;
	#$c->stats->profile("Got party's location");

    my ($start_point, $end_point) = RPG::Map->surrounds(
                                        $party_location->x,
                                        $party_location->y,
                                        $c->config->{map_x_size},
                                        $c->config->{map_y_size},
                                    );
                                    
	#$c->stats->profile("Got start and end point");                                    
    
    my @area = $c->model('Land')->search(
        {
            'x' => {'>=', $start_point->{x},'<=', $end_point->{x}},
            'y' => {'>=', $start_point->{y},'<=', $end_point->{y}},
        },
        {
        	prefetch => 'terrain',
        },
    );
    
    #$c->stats->profile("Queried db for sectors");
    
    my @grid;
    
    foreach my $location (@area) {
        $grid[$location->x][$location->y] = $location;
    }
    
    #$c->stats->profile("Built grid");
    
    return $c->forward('RPG::V::TT',
        [{
            template => 'map/generate_map.html',
            params => {
                grid => \@grid,
                current_position => $party_location,
                party_movement_factor => $c->stash->{party}->movement_factor,
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
    
    my $new_land = $c->model('Land')->find( 
    	$c->req->param('land_id'),
    	{
    		prefetch => 'terrain',
    	},
    );
    
    unless ($new_land) {
        $c->stash->{error} = 'Land does not exist!';
        $c->detach($c->action);    
    }
    
    # Check that the new location is actually next to current position.
    unless ($c->stash->{party}->location->next_to($new_land)) {
        $c->stash->{error} = 'You can only move to a location next to your current one';
        $c->detach($c->action);
    }    
    
    # Check that the party has enough movement points
    my $movement_factor = $c->stash->{party}->movement_factor;
    unless ($c->stash->{party}->turns >= $new_land->movement_cost($movement_factor)) {
        $c->stash->{error} = 'You do not have enough movement points to move there';
        $c->detach($c->action);  
    }
        
    $c->stash->{party}->land_id($c->req->param('land_id'));
    $c->stash->{party}->turns($c->stash->{party}->turns - $new_land->movement_cost($movement_factor));
    $c->stash->{party}->update;
    
    $c->res->redirect('/');    
}

1;