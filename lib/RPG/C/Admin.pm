package RPG::C::Admin;

use strict;
use warnings;
use base 'Catalyst::Controller';

sub auto : Private {
	my ($self, $c) = @_;
		
	return 0 unless $c->session->{player}->admin_user;
}

sub default : Path {
	my ($self, $c) = @_;
	
	$c->forward('/admin/items/edit_item_type');
}

sub login_as : Local {
	my ($self, $c) = @_;
	
	if ($c->req->param('submit')) {
	    my %args;
	    if ($c->req->param('email')) {
	        $args{email} = $c->req->param('email');
	    }
	    elsif ($c->req->param('player_name')) {
	        $args{player_name} = $c->req->param('player_name');
	    }
	    else {
	        return;
	    }	    
	    
	    my $player = $c->model('DBIC::Player')->find(
	       {
	           %args,
	       }
	    ); 
	    
        $c->session->{player} = $player;
        $c->res->redirect( $c->config->{url_root} );
        return;
	}
	
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'admin/login_as.html',
                params   => {},
            }
        ]
    );	
    
}

1;