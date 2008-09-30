package RPG::C::Root;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use Carp qw(cluck);

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

sub auto : Private {
    my ( $self, $c ) = @_;
    
    $c->req->base($c->config->{url_root});
        
    if (! $c->session->{player}) {
    	if ($c->action !~ m|^player|) {
    		$c->detach('/player/login');
    	}
    	return 1;
    }

    return 1 if $c->action =~ m/^admin/;
       
    $c->stash->{party} = $c->model('DBIC::Party')->find(
    	{
    		player_id => $c->session->{player}->id,
    		defunct => undef,
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
	    # TODO: clean up this logic!
	    if ($c->stash->{party}->in_combat_with && $c->action ne 'party/main' && $c->action !~ m|^combat| && $c->action ne 'party/select_action'
	    	&& $c->action ne '/' && $c->action ne 'player/logout') {
	    	$c->debug('Forwarding to /party/main since party is in combat');
	    	$c->stash->{error} = "You must flee before trying to move away!";
	    	$c->forward('/party/main');
	    	return 0;
	    }
	    
	    # Check if they're due a new day
	    if (! $c->stash->{party}->in_combat_with && $c->stash->{party}->new_day_due) {
	    	$c->forward('/party/process_new_day');
	    }   

    }
    elsif ($c->action !~ m|^party/create| && $c->action ne 'player/logout') {
    	$c->res->redirect($c->config->{url_root} . '/party/create/create');
    	return 0;
    }
        
    return 1;
    
}

sub default : Private {
    my ( $self, $c ) = @_;
    
	$c->forward('/party/main');
}

sub end : Private {
	my ( $self, $c ) = @_;

    if ( scalar @{ $c->error } ) {
    	$c->model('DBIC')->schema->storage->dbh->rollback;
    	
    	# Log error message
    	$c->log->error('An error occured...');
    	$c->log->error("Action: " . $c->action);
    	$c->log->error("Path: " . $c->req->path);
    	$c->log->error("Params: " . Dumper $c->req->params);
    	$c->log->error("Player: " . $c->session->{player}->id) if $c->session->{player};
    	$c->log->error("Party: " . $c->stash->{party}->id) if $c->stash->{party};

    	foreach my $err_str (@{ $c->error }) {
    		$c->log->error($err_str);
    	}
        
        # Display error page        
        $c->forward('RPG::V::TT',
 	       [{
				template => 'error.html',
				params => {
					error_msgs => $c->error,
				},
		   }]
		);            

        $c->error(0);
	}
	else {
		$c->model('DBIC')->schema->storage->dbh->commit;	
	}

    return 1 if $c->response->status =~ /^3\d\d$/;
    return 1 if $c->response->body;

    unless ( $c->response->content_type ) {
        $c->response->content_type('text/html; charset=utf-8');
    }
}

1;
