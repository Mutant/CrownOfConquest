package RPG::C::Player;

use strict;
use warnings;
use base 'Catalyst::Controller';

use MIME::Lite;
use String::Random;

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
			if ($user->verified) {
				$c->session->{player} = $user;
				$c->res->redirect($c->config->{url_root});
			}
			else {
				$c->res->redirect($c->config->{url_root} . "/player/verify?email=" . $c->req->param('email'));
			}
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
		elsif (length $c->req->param('password1') < $c->config->{minimum_password_length} ) {
			$message = "Password must be at least " . $c->config->{minimum_password_length} . " characters";
		}
		else {
			my $verification_code = String::Random::random_regex('\w{8}');
			
			my $player = $c->model('DBIC::Player')->create(
				{
					player_name => $c->req->param('player_name'),
					email => $c->req->param('email'),
					password => $c->req->param('password1'),
					verification_code => $verification_code,
				}
			);
			
			my $msg = MIME::Lite->new(
		        From     => $c->config->{send_email_from},
		        To       => $c->req->param('email'),
		        Subject  =>'Verification code',
		        Data     => "Your verification code is: $verification_code\n",
		    );
			$msg->send(
				'smtp', 
				$c->config->{smtp_server},
	       		AuthUser=>$c->config->{smtp_user}, 
	       		AuthPass=>$c->config->{smtp_pass},
	       		Debug => 0,
			);
			
			$c->res->redirect($c->config->{url_root} . "/player/verify?email=" . $c->req->param('email'));
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

sub forgot_password : Local {
	my ($self, $c) = @_;
	
	my $message = 'Enter your email address below, and a reset password will be mailed to you.';
	
	if ($c->req->param('email')) {
		my $new_password = String::Random::random_regex('\w{8}');
		
		my $player = $c->model('DBIC::Player')->find(
			{
				email => $c->req->param('email'),
			}
		);
		
		if ($player) {		
			$player->password($new_password);
			$player->update;
			
			my $msg = MIME::Lite->new(
		        From     => $c->config->{send_email_from},
		        To       => $c->req->param('email'),
		        Subject  =>'Reset Password',
		        Data     => "Your password has been reset. It's now: $new_password\n",
		    );
			$msg->send(
				'smtp', 
				$c->config->{smtp_server},
	       		AuthUser=>$c->config->{smtp_user}, 
	       		AuthPass=>$c->config->{smtp_pass},
	       		Debug => 1,
			);
			
			$message = 'A new password has been sent to you.';
		}
		else {
			$message = "Can't find that email address in the DB!";
		}
	}
	
	$c->forward('RPG::V::TT',
        [{
            template => 'player/forgot_password.html',
			params => {
				message => $message,
			},
        }]
    );		
}

sub captcha : Local {
	my ($self, $c) = @_;
    $c->create_captcha();
}

sub change_password : Local {
	my ($self, $c) = @_;
	
	my $message;
	
	if ($c->req->param('current_password')) {
		if ($c->req->param('current_password') ne $c->session->{player}->password) {
			$c->stash->{error} = "Current password is incorrect";
		}
		elsif ($c->req->param('new_password') ne $c->req->param('retyped_password')) {
			$c->stash->{error} = "New passwords don't match";	
		}
		elsif (length $c->req->param('new_password') < $c->config->{minimum_password_length} ) {
			$c->stash->{error} = "New password must be at least " . $c->config->{minimum_password_length} . " characters";
		}
		else {
			my $player = $c->model('DBIC::Player')->find(
				player_id => $c->session->{player}->id,
			);
			
			$player->password($c->req->param('new_password'));
			$player->update;
			
			$c->session->{player} = $player;
			
			$message = 'Password changed';
		}
	}
	
	$c->forward('RPG::V::TT',
        [{
            template => 'player/change_password.html',
			params => {
				message => $message,
			},
        }]
    );
}

sub verify : Local {
	my ($self, $c) = @_;
	
	my $message;
	
	if ($c->req->param('verification_code')) {
		my $player = $c->model('DBIC::Player')->find(
			email => $c->req->param('email'),
		);
		
		if ($player) {
			if ($player->verification_code eq $c->req->param('verification_code')) {
				$player->verified(1);
				$player->update;
				$c->session->{player} = $player;
				
				$c->res->redirect($c->config->{url_root});
				
				return;
			}
			else {
				$message = "Verifcation code incorrect";
			}
		}
		else {
			$message = "Can't find that email address... make sure you've already registered";
		}
	}
	
	$c->forward('RPG::V::TT',
        [{
            template => 'player/verify.html',
			params => {
				message => $message,
				email => $c->req->param('email'),
			},
			fill_in_form => 1,
        }]
    );
}

1;
