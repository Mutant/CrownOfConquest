package RPG::C::Root;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

sub auto : Private {
    my ( $self, $c ) = @_;
    
    unless ($c->session->{player}) {
    	$c->detach('/player/login');
    }
    
    warn Dumper [keys %{$c->session}];
    warn "action params: " . Dumper $c->session->{combat_action_param};
    
    $c->stash->{party} = $c->model('DBIC::Party')->find(
    	{
			# Assumes 1 party per player...
    		player_id => $c->session->{player}->id,
    	},
    	{
    		prefetch => [
    			{'characters' => 
    				[
    					'race', 
    					'class',
    					{'character_effects' => 'effect'},
    				]
    			},
    			{'location' => 'town'},
    		],
    		order_by => 'party_order',
    	},
    );
    
    if ($c->stash->{party} && $c->stash->{party}->created) {    
	    $c->stash->{party_location} = $c->stash->{party}->location;
	            
	    # If the party is currently in combat, they must stay on the combat screen
	    if ($c->stash->{party}->in_combat_with && $c->action ne 'party/main' && $c->action !~ m|^combat/|
	    	&& $c->action !~ m|^admin/|) {
	    	$c->stash->{error} = "You must flee before trying to move away!";
	    	$c->forward('/party/main');
	    	return 0;
	    }
    }
    elsif ($c->action !~ m|^party/create|) {
    	$c->res->redirect('/party/create/create');
    	return 0;
    }
    
    return 1;
    
}

sub default : Private {
    my ( $self, $c ) = @_;
    
	$c->forward('/party/main');
}

1;
