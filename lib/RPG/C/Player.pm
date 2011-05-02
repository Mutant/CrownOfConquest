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
use Digest::SHA1 qw(sha1_hex);
use MIME::Lite;
use Data::Dumper;

sub login : Local {
    my ( $self, $c ) = @_;

    my $message;
    
    if ( $c->req->param('email') ) {
        my $user = $c->model('DBIC::Player')->find( { 
        	email => $c->req->param('email'), 
        	password => sha1_hex $c->req->param('password') 
        });

        if ($user) {
            $user->last_login( DateTime->now() );
            # Only clear warned for deletion if they're not deleted. Deleted users will get that cleared later
            #  when they reactivate (in Root.pm).
            $user->warned_for_deletion(0) unless $user->deleted;
            $user->update;

            if ( $user->verified ) {
                $c->session->{player} = $user;
                $c->session->{partial_login} = 0;
                                
                # Various post login checks
                $c->forward('post_login_checks');
                
                my $url_to_redirect_to = $c->session->{login_url} || '';
                undef $c->session->{login_url};
                
                $c->log->info("Post login redirect to: $url_to_redirect_to");
                
                if ($url_to_redirect_to =~ m|player/login|) {
                	$url_to_redirect_to = ''; # Don't redirect back to the login page	
                }
                              
                $c->res->redirect( $c->config->{url_root} . $url_to_redirect_to );
                return;
            }
            else {
                $c->res->redirect( $c->config->{url_root} . "/player/verify?email=" . $c->req->param('email') );
                return;
            }
        }
        else {
            $message = "Email address and/or password incorrect";
        }
    }
    else {
    	unless ($c->req->uri->path =~ /favicon/) { 
    		$c->log->debug("Saving redirect url: " . $c->req->uri->path);
        	$c->session->{login_url} = $c->req->uri->path;
    	}	
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

# Allows login via a random hash send via email, so only one click is necessary to login
#  This is only a 'partial' login though - only gives access to a couple of screens
sub email_login : Local {
    my ( $self, $c ) = @_;
    
    my $user = $c->model('DBIC::Player')->find( { 
    	email => $c->req->param('email'), 
    	email_hash => $c->req->param('h'), 
    });
    
    return unless $user;
    
    $user->email_hash(undef);
    $user->update;
    
    $c->session->{player} = $user;
    $c->session->{partial_login} = 1;
    
    # For now, we hard-code in a redirect, but could be parameteised later
    $c->res->redirect( '/player/account/email_unsubscribe' );    
    
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
            
            my $code;
            if ($c->req->param('promo_code')) {
            	$code = $c->model('DBIC::Promo_Code')->find(
            		{
            			code => $c->req->param('promo_code'),
            			used => 0,
            		},
            		{
            			prefetch => 'promo_org',
            		},            	
            	);
            	
            	if ($code) {            		
            		$c->flash->{promo_org_message} = $c->forward(
	                    'RPG::V::TT',
	                    [
	                        {
	                            template      => 'player/promo_org_message.html',
	                            params        => { code => $code, },
	                            return_output => 1,
	                        }
	                    ]
	                );
            	}
            }
            
            my $player = $c->model('DBIC::Player')->create(
                {
                    player_name       => $c->req->param('player_name'),
                    email             => $c->req->param('email'),
                    password          => sha1_hex($c->req->param('password1')),
                    verification_code => $verification_code,
                    last_login        => DateTime->now(),
                    $code ? (promo_code_id => $code->code_id) : (),
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
        my $party = $c->model('DBIC::Party')->find(
            { player_id => $c->session->{player}->id, },
            {
                order_by => 'defunct desc',
                rows     => 1,
            },
        );

		unless ($party) {
        	$c->log->warn("Old party not found... generating a new one");
        	$party = $c->model('DBIC::Party')->create(
        		{
        			player_id => $c->session->{player}->id,,
				},
        	);
		}
		else {
        	$party->defunct(undef);
        	$party->update;
		}

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
            $player->password(sha1_hex($new_password));
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
                $player->last_login( DateTime->now() );
                $player->warned_for_deletion(0);
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
    elsif (my $org_message = $c->flash->{promo_org_message}) {
    	$message = $org_message;
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

sub survey : Local {
	my ( $self, $c ) = @_;
	
	my $reason = join ',', $c->req->param('reason');
	$reason .= ','.$c->req->param('reason_other');

	my $survey = {
			reason => $reason,
			favourite => $c->req->param('favourite'),
			least_favourite => $c->req->param('least_favourite'),
			feedback => $c->req->param('feedback'),
			email => $c->req->param('email'),
			party_level => $c->session->{party_level},
			turns_used => $c->session->{turns_used},
	};
	
	my $survey_resp = $c->model('DBIC::Survey_Response')->create(
		$survey,
	);
	
	my $msg = MIME::Lite->new(
		From    => $c->config->{send_email_from},
		To      => $c->config->{send_email_from},
		Subject => '[Kingdoms] Survey Response',
		Data    => "A survey was completed. The response was:\n\n" . Dumper $survey,
	);
	$msg->send( 'smtp', $c->config->{smtp_server}, Debug => 0, );	
	
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

sub reward_callback : Local : Args(1) {
    my ($self, $c, $site_name) = @_;

    my $link = $c->model('DBIC::Reward_Links')->find(
        {
            name => $site_name,
        },
    );
    
    $c->log->info("Got reward callback for site: $site_name");
    
    return unless $link;
    
    if ($link->result_field) {
        my $result = $c->req->param($link->result_field);
        
        if (! $result) {
            $c->log->info("Result is: $result, not giving a reward");
            return;   
        }       
    }
    
    my %params;
    $params{player_id} = $c->req->param($link->user_field);
    $params{vote_key} = $c->req->param($link->key_field)
        if defined $link->key_field;
    
    my $player_reward_link = $c->model('DBIC::Player_Reward_Links')->find(
        {
            %params,
            link_id => $link->id,           
        },
    );
    
    if ($player_reward_link) {
        $c->log->info("Received message for successful action for player: " . $params{player_id});
        
        if ($player_reward_link->last_vote_date && DateTime->compare($player_reward_link->last_vote_date, DateTime->now()->subtract( hours => 24 )) == 1) {
            $c->log->info("Voted for this site in last 24 hours, ignoring");
            return; 
        }
        
        my $party = $c->model('DBIC::Party')->find(
            {
                player_id => $params{player_id},
                defunct => undef,
            }
        );
        $party->_turns($party->_turns + $link->turn_rewards);
        $party->update;
        
        $player_reward_link->last_vote_date(DateTime->now());
        $player_reward_link->update;
        
        my $today = $c->model('DBIC::Day')->find_today;
        
    	$c->model('DBIC::Party_Messages')->create(
    		{
    			message => "You received " . $player_reward_link->link->turn_rewards . " turns for voting for Kingdoms at " . $link->label,
    			alert_party => 1,
    			party_id => $party->id,
    			day_id => $today->id,
    		}
    	);          
    }    
}

1;
