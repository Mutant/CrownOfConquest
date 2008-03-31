package RPG::C::Root;

use strict;
use warnings;
use base 'Catalyst::Controller';

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

sub auto : Private {
    my ( $self, $c ) = @_;
    
    $c->stats->profile(begin => 'auto');
    
    # XXX: player id hard coded for now (need to implement login)
    $c->session->{player_id} = 1;
    $c->session->{party_id}  = 1;
    
    $c->log->debug($c->req->headers->as_string);
    
    $c->stats->profile("Running party query");
    
    $c->stash->{party} = $c->model('Party')->find(
    	{
    		party_id => $c->session->{party_id},
    	},
    	{
    		prefetch => [{'characters' => ['race', 'class']}],
    		cache => 1,
    		order_by => 'party_order',
    	},
    );
    
    $c->stats->profile("Finished party query");
    
    # If the party is currently in combat, they must stay on the combat screen
    if ($c->stash->{party}->in_combat_with && $c->action ne 'party/main' && $c->action !~ m|^combat/|) {
    	$c->stash->{error} = "You must flee before trying to move away!";
    	$c->forward('/party/main');
    	return 0;
    }
    
    $c->stats->profile(end => 'auto');
    
    return 1;
    
}

sub default : Private {
    my ( $self, $c ) = @_;
    
    if ($c->session->{player_id}) {
    	if ($c->stash->{party}) {
    		$c->forward('/party/main');
    	}
    	else {
    		$c->forward('/party/create');
    	}
    }
    else {
    	# Login
    }

    
}



1;
