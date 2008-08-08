package RPG::C::Player;

use strict;
use warnings;
use base 'Catalyst::Controller';

sub login : Local {
	my ($self, $c) = @_;
	
	my $message;
	
	if ($c->req->param('email')) {
		my $user = $c->model('DBIC::Player')->find(
			{
				email => $c->req->param('email'),
			}
		);
		
		if ($user) {
			$c->session->{player} = $user;
			$c->res->redirect($c->config->{url_root});
		}
		else {
			$message = "Email address and/or password incorrect";	
		}
	}
	
	$c->forward('RPG::V::TT',
        [{
            template => 'player/login.html',
			params => {
				message => $message,
			},
        }]
    );	
}

sub logout : Local {
	my ($self, $c) = @_;
	
	$c->delete_session;
	$c->res->redirect($c->config->{url_root});		
}

1;
