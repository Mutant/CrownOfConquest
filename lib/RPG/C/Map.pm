package RPG::C::Map;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;

sub auto : Private {
    my ($self, $c) = @_;

    $c->stash->{party} = $c->model('Party')->find( 
    	$c->session->{party_id},
    	{
    		prefetch => 'location',
    	},
	);
    
    return 1;
}

sub view : Local {
    my ($self, $c) = @_;
    
    my $party_location = $c->stash->{party}->location;
    
    # See if party is in same location as a creature
    my @creatures = $c->model('DBIC::CreatureGroup')->search(
        {
            'x' => $party_location->x,
            'y' => $party_location->y,
        },
        {
            join => 'location',
        },
    );

    # XXX: we should only ever get one creature group from above, since creatures shouldn't move into
    #  the same square as another group. May pay to check this here and alert if there are more than one.
    #  At any rate, we'll just look at the first group.        
    my $creature_group = shift @creatures;
   
    
    # If there are creatures here, check to see if we go straight into an encounter
    if ($creature_group) {
        # Do they notice the party?
        my $party_noticed = $c->config->{creature_notice_chance} <= int rand 100;
        
        # Do they decide to attack the party?
        my $decide_to_attack = $c->config->{creature_attack_chance} <= int rand 100;
        
        if ($party_noticed && $decide_to_attack) {
            # XXX: Combat starts
            return;
        }
    }    
        
    # Display normal sector menu
    $c->forward('/map/generate_map');
}

sub generate_map : Private {
    my ($self, $c) = @_;
    
    my $party_location = $c->stash->{party}->location;

    my ($start_point, $end_point) = RPG::Map->surrounds(
                                        $party_location->x,
                                        $party_location->y,
                                        $c->config->{map_x_size},
                                        $c->config->{map_y_size},
                                    );
    
    my @area = $c->model('Land')->search(
        {
            'x' => {'>=', $start_point->{x},'<=', $end_point->{x}},
            'y' => {'>=', $start_point->{y},'<=', $end_point->{y}},
        },
        {
        	prefetch => 'terrain',
        },
    );
    
    my @grid;
    
    foreach my $location (@area) {
        $grid[$location->x][$location->y] = $location;
    }
    
    return $c->forward('RPG::V::TT',
        [{
            template => 'map/view.html',
            params => {
                grid => \@grid,
                current_position => $party_location->id,
            },
            #return_output => 1,
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
        $c->detach('/map/view');    
    }
    
    # Check that the new location is actually next to current position.
    unless ($c->stash->{party}->location->next_to($new_land)) {
        $c->stash->{error} = 'You can only move to a location next to your current one';
        $c->detach('/map/view');
    }    
    
    # Check that the party has enough movement points
    unless ($c->stash->{party}->movement_points >= $new_land->terrain->modifier + 1) {
        $c->stash->{error} = 'You do not have enough movement points to move there';
        $c->detach('/map/view');  
    }
        
    $c->stash->{party}->land_id($c->req->param('land_id'));
    $c->stash->{party}->movement_points($c->stash->{party}->movement_points - ($new_land->terrain->modifier + 1));
    $c->stash->{party}->update;
    
    $c->res->redirect('/map/view');    
}

1;