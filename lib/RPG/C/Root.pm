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
    
    # XXX: player id hard coded for now (need to implement login)
    $c->session->{player_id} = 1;
    $c->session->{party_id} = 1;
    
}

sub default : Private {
    my ( $self, $c ) = @_;
    
    if ($c->session->{player_id}) {
    	if ($c->session->{party_id}) {
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
