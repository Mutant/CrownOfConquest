package RPG::C::Player;

use strict;
use warnings;
use base 'Catalyst::Controller';

use RPG::Email;
use DateTime;
use Carp;

use String::Random;
use DateTime;
use List::Util qw(shuffle);

sub login : Local {
    my ( $self, $c ) = @_;

    my $message;
    
    if ( $c->req->param('email') ) {
        my $user = $c->model('DBIC::Player')->find( { email => $c->req->param('email'), password => $c->req->param('password') } );

        if ($user) {
            $user->last_login( DateTime->now() );
            # Only clear warned for deletion if they're not deleted. Deleted users will get that cleared later
            #  when they reactivate (in Root.pm).
            $user->warned_for_deletion(0) unless $user->deleted;
            $user->update;

            if ( $user->verified ) {
                $c->session->{player} = $user;
                                
                # Various post login checks
                $c->forward('post_login_checks');
                
                my $url_to_redirect_to = $c->session->{login_url} || '';
                undef $c->session->{login_url};
                
                $c->log->info("Post login redirect to: $url_to_redirect_to");
                
                if ($url_to_redirect_to =~ m|player/login|) {
                	$url_to_redirect_to = ''; # Don't redirect back to the login page	
                }
                              
                $c->res->redirect( $c->config->{url_root} . $url_to_redirect_to );
            }
            else {
                $c->res->redirect( $c->config->{url_root} . "/player/verify?email=" . $c->req->param('email') );
            }
        }
        else {
            $message = "Email address and/or password incorrect";
        }
    }
    else {
    	$c->log->debug("Saving redirect url: " . $c->req->uri->path);
        $c->session->{login_url} = $c->req->uri->path;	
    }

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'player/login.html',
                params   => { message => $message, },
            }
        ]
    );
}

sub post_login_checks : Private {
	my ($self, $c) = @_;
                
    my $player = $c->session->{player};
                
    # Check for announcements
	my @announcements = $c->model('DBIC::Announcement')->search(
    	{
       		'announcement_player.player_id' => $player->id,
       		'announcement_player.viewed' => 0,                		
       	},
       	{
      		'order_by' => 'date desc',
       		'join' => 'announcement_player',
       	}
    );
                
    $c->session->{announcements} = \@announcements if scalar @announcements > 0;
    
    # Check for tip of the day
    if ($player->display_tip_of_the_day) {
    	my @tips = shuffle $c->model('DBIC::Tip')->search();
    	
    	my $tip = $tips[0];
    	
    	$c->flash->{tip} = $tip if $tip;
    }
}

sub logout : Local {
    my ( $self, $c ) = @_;

    $c->delete_session;
    $c->res->redirect( $c->config->{url_root} );
}

sub register : Local {
    my ( $self, $c ) = @_;

    if ( $c->model('DBIC::Player')->count( { deleted => 0 } ) >= $c->config->{max_number_of_players} ) {
        $c->forward( 'RPG::V::TT', [ { template => 'player/full.html', } ] );
        return;
    }

    my $message;

    if ( $c->req->param('submit') ) {
        $message = eval {
            unless ( $c->req->param('email')
                && $c->req->param('player_name')
                && $c->req->param('password1')
                && $c->req->param('password1') eq $c->req->param('password2')
                && $c->validate_captcha( $c->req->param('captcha') ) )
            {

                return "Please enter your email address, name, password and the CAPTCHA code";

            }

            if ( length $c->req->param('password1') < $c->config->{minimum_password_length} ) {
                return "Password must be at least " . $c->config->{minimum_password_length} . " characters";
            }

            my $existing_player = $c->model('DBIC::Player')->find( { email => $c->req->param('email') }, );

            if ($existing_player) {
                return $c->forward(
                    'RPG::V::TT',
                    [
                        {
                            template      => 'player/already_exists.html',
                            params        => { email => $c->req->param('email'), },
                            return_output => 1,
                        }
                    ]
                );
            }
            
            $existing_player = $c->model('DBIC::Player')->find( { player_name => $c->req->param('player_name') }, );
            
            if ($existing_player) {
            	return "A player with the name '" . $c->req->param('player_name') . "' is already registered";	
            }
            
            my $verification_code = _generate_and_send_verification_code( $c, $c->req->param('email') );
            
            my $player = $c->model('DBIC::Player')->create(
                {
                    player_name       => $c->req->param('player_name'),
                    email             => $c->req->param('email'),
                    password          => $c->req->param('password1'),
                    verification_code => $verification_code,
                    last_login        => DateTime->now(),
                }
            );
 
            $c->res->redirect( $c->config->{url_root} . "/player/verify?email=" . $c->req->param('email') );

            return;
        };
	    if (my $error = $@) {
	        confess $error;
	    }

        return unless $message;
    }

    $c->forward(
        'RPG::V::TT',
        [
            {
                template     => 'player/register.html',
                params       => { message => $message, },
                fill_in_form => 1,
            }
        ]
    );
}

sub _generate_and_send_verification_code {
    my $c          = shift;
    my $to_address = shift;

    my $verification_code = ( int rand 100000000 + int rand 100000000 );

    my $email_message = $c->forward(
        'RPG::V::TT',
        [
            {
                template      => 'player/email/verfication.txt',
                params        => { 
                    verification_code => $verification_code,
                    email => $c->req->param('email'), 
                },
                return_output => 1,
            }
        ]
    );

    RPG::Email->send(
    	$c->config,
    	{
	        email      => $to_address,
	        subject => 'Verification code',
	        body    => $email_message,
    	}
    );

    return $verification_code;
}

sub reverify : Local {
    my ( $self, $c ) = @_;

    my $message;

    if ( $c->req->param('email') ) {
        $message = eval {
            my $player = $c->model('DBIC::Player')->find( { email => $c->req->param('email'), } );

            return "Your email address is not registered. Please register first" unless defined $player;

            if ($player) {
                if ( $player->verified == 1 ) {
                    return "You're already verified! Please login to play.";
                }

                my $verification_code = _generate_and_send_verification_code( $c, $c->req->param('email') );

                $player->verification_code($verification_code);
                $player->update;

                return "A new verification code has been sent to you. If you continue to have problems, please post about it in the Forum";
            }
        };
        if ($@) {
            croak $@;
        }
    }

    $c->forward(
        'RPG::V::TT',
        [
            {
                template     => 'player/reverify.html',
                params       => { message => $message, },
                fill_in_form => 1,
            }
        ]
    );

}

sub reactivate : Local {
    my ( $self, $c ) = @_;

    if ( $c->req->param('reform_party') ) {
        my $old_party = $c->model('DBIC::Party')->find(
            { player_id => $c->session->{player}->id, },
            {
                order_by => 'defunct desc',
                rows     => 1,
            },
        );

        croak "Old party not found\n" unless $old_party;

        $old_party->defunct(undef);
        $old_party->update;

        $c->res->redirect( $c->config->{url_root} );

        return;
    }

    $c->forward( 'RPG::V::TT', [ { template => 'player/reactivate.html', } ] );
}

sub forgot_password : Local {
    my ( $self, $c ) = @_;

    my $message;

    if ( $c->req->param('email') ) {

        my $new_password = String::Random::random_regex('\w{8}');

        my $player = $c->model('DBIC::Player')->find( { email => $c->req->param('email'), } );

        if ($player) {
            $player->password($new_password);
            $player->update;

            my $email_message = $c->forward(
                'RPG::V::TT',
                [
                    {
                        template      => 'player/email/new_password.txt',
                        params        => { new_password => $new_password, },
                        return_output => 1,
                    }
                ]
            );

            RPG::Email->send(
            	$c->config,
            	{
                	email   => $c->req->param('email'),
                	subject => 'Reset Password',
              		body    => $email_message,
            	}
            );
            
            $message = 'A new password has been sent to you.';
        }
        else {
            $message = "Can't find that email address in the DB!";
        }
    }

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'player/forgot_password.html',
                params   => { message => $message, },
            }
        ]
    );
}

sub captcha : Local {
    my ( $self, $c ) = @_;
    $c->create_captcha();
}

sub verify : Local {
    my ( $self, $c ) = @_;

    my $message;

    if ( $c->req->param('verification_code') ) {
        my $player = $c->model('DBIC::Player')->find( { email => $c->req->param('email'), } );

        if ($player) {
            if ( $player->verification_code eq $c->req->param('verification_code') ) {
                $player->verified(1);
                $player->update;
                $c->session->{player} = $player;

                $c->res->redirect( $c->config->{url_root} );

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

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'player/verify.html',
                params   => {
                    message => $message,
                    email   => $c->req->param('email'),
                },
                fill_in_form => 1,
            }
        ]
    );
}

sub about : Local {
    my ( $self, $c ) = @_;

    $c->forward( 'RPG::V::TT', [ { template => 'player/about.html', } ] );
}

sub screenshots : Local {
    my ( $self, $c ) = @_;

    $c->forward( 'RPG::V::TT', [ { template => 'player/screenshots.html', } ] );
}

sub vote : Local {
    my ( $self, $c ) = @_;

    $c->forward( 'RPG::V::TT', [ { template => 'player/vote.html', } ] );
}

sub survey : Local {
	my ( $self, $c ) = @_;
	
	my $reason = join ',', $c->req->param('reason');
	$reason .= ','.$c->req->param('reason_other');
	
	my $survey_resp = $c->model('DBIC::Survey_Response')->create(
		{
			reason => $reason,
			favourite => $c->req->param('favourite'),
			least_favourite => $c->req->param('least_favourite'),
			feedback => $c->req->param('feedback'),
			email => $c->req->param('email'),
			party_level => $c->session->{party_level},
			turns_used => $c->session->{turns_used},
		}
	);
	
	$c->forward( 'RPG::V::TT', [ { template => 'player/survey_thanks.html', } ] );
	
}

sub announcements : Local {
	my ( $self, $c ) = @_;
	
	my @announcements = $c->model('DBIC::Announcement')->search(
		{},
		{
			order_by => 'date desc',
		}
	);
	
	$c->forward( 'RPG::V::TT', [ 
		{ 
			template => 'player/announcement/list.html',
			params => {
				announcements => \@announcements,
			} 
		} 
	] );	
}

1;
