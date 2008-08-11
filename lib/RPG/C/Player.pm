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

sub register : Local {
	my ($self, $c) = @_;
	
	if ($c->model('DBIC::Player')->count >= $c->config->{max_number_of_players}) {
		$c->forward('RPG::V::TT',
	        [{
	            template => 'player/full.html',
	        }]
	    );
	    return;
	}
	
	my $message;
	
	if ($c->req->param('submit')) {
		unless ($c->req->param('email') && $c->req->param('player_name') && $c->req->param('password1') 
			&& $c->req->param('password1') eq $c->req->param('password2') && 
			$c->validate_captcha($c->req->param('captcha'))) {
		
			$message = "Please enter your email address, name, password and the CAPTCHA code";
				
		}
		else {
			my $player = $c->model('DBIC::Player')->create(
				{
					player_name => $c->req->param('player_name'),
					email => $c->req->param('email'),
					password => $c->req->param('password1'),
				}
			);	
			
			$c->session->{player} = $player;
			$c->res->redirect($c->config->{url_root});
		}
	}
	
	$c->forward('RPG::V::TT',
        [{
            template => 'player/register.html',
			params => {
				message => $message,
			},
			fill_in_form => 1,
        }]
    );	
}

sub captcha : Local {
	my ($self, $c) = @_;
    $c->create_captcha();
}

1;
