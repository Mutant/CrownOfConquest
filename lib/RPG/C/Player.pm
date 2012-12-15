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
use HTML::Strip;
use Email::Valid;

use feature 'switch';

sub login : Local {
    my ( $self, $c ) = @_;

    my $message;
    
    if ( $c->req->param('login') ) {
        my @users = $c->model('DBIC::Player')->search( { 
         	'-or' => {
                email => $c->req->param('login'),
            	player_name => $c->req->param('login'),
         	},
            password => sha1_hex $c->req->param('password'),             
        });
        
        my $user = $users[0];
        
        if ($user) {
            $c->forward('login_user', [$user]);
            
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
            $message = "Email address and/or password incorrect";
        }
    }
    else {
    	unless ($c->req->uri->path =~ /favicon/) { 
    		$c->log->debug("Saving redirect url: " . $c->req->uri->path);
        	$c->session->{login_url} = $c->req->uri->path;
    	}	
    }
    
    my $last_announcement = $c->model('DBIC::Announcement')->search(
        {},
        {
            rows => 1,
            order_by => { -desc => 'date' },
        },
    )->first;
            

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'player/login.html',
                params   => { 
                    message => $message,
                    last_announcement => $last_announcement, 
                },
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

sub set_screen_size : Private {
    my ( $self, $c ) = @_;    
    
    my $player = $c->session->{player};
    
    # Set screen size in session
    $c->session->{screen_width} = $player->screen_width;
    if ($player->screen_width eq 'auto') {
        given ($c->req->param('width')) {
            when ($_ >= 1200) {
                $c->session->{screen_width} = 'large';
            }
            when ($_ >= 1100) {
                $c->session->{screen_width} = 'medium';
            }
            default {                
                $c->session->{screen_width} = 'small';
            }
        }    
    }
    
    $c->session->{screen_height} = $player->screen_height;
    if ($player->screen_height eq 'auto') {
        given ($c->req->param('height')) {
            when ($_ >= 750) {
                $c->session->{screen_height} = 'large';
            }
            when ($_ >= 650) {
                $c->session->{screen_height} = 'medium';
            }
            default {                
                $c->session->{screen_height} = 'small';
            }
        }    
    }    
    
    $c->log->info("Screen height: " . $c->session->{screen_height} . "; Screen width: " . $c->session->{screen_width});
}

sub update_screen_sizes : Local {
    my ( $self, $c ) = @_;    
    
    my $player = $c->model('DBIC::Player')->find($c->session->{player}->id);
    
    $player->screen_width($c->req->param('screen_width'));
    $player->screen_height($c->req->param('screen_height'));
    $player->update;
    
    $c->session->{player} = $player;
    
    $c->forward('set_screen_size');
    
    $c->stash->{panel_messages} = 'Changes Saved';

    $c->forward('/party/details/options');    
    
}

sub logout : Local {
    my ( $self, $c ) = @_;

    $c->delete_session;
    $c->res->redirect( $c->config->{url_root} );
}

sub register : Local {
    my ( $self, $c ) = @_;

    if ( $c->model('DBIC::Player')->count( { deleted => 0 } ) >= $c->config->{max_number_of_players} ) {
        $c->forward( 'RPG::V::TT', [ { template => 'player/full.html' } ] );
        return;
    }

    my $message;

    if ( $c->req->param('submit') ) {
        my $hs = HTML::Strip->new();
        my $name = $hs->parse($c->req->param('player_name'));
        
        $message = eval {
            unless ( $name
                && $c->req->param('password1')
                && $c->req->param('password1') eq $c->req->param('password2')
                && $c->validate_captcha( $c->req->param('captcha') ) )
            {
                return "Please enter your name, password and the CAPTCHA code";
            }

            if ( length $c->req->param('password1') < $c->config->{minimum_password_length} ) {
                return "Password must be at least " . $c->config->{minimum_password_length} . " characters";
            }
            
            my $email_error = $c->forward('check_email', [$c->req->param('email')]);
            
            return $email_error if $email_error;
            
            
            my $existing_player = $c->model('DBIC::Player')->find( { player_name => $c->req->param('player_name') }, );
            
            if ($existing_player) {
            	return "A player with the name '" . $c->req->param('player_name') . "' is already registered";	
            }
            
            my $referring_player;
            if ($c->req->param('referred_by') || $c->req->param('referred_by_email')) {
                $referring_player = $c->model('DBIC::Player')->search( 
                    { 
                        '-or' => {
                            player_name => $c->req->param('referred_by'),
                            email => $c->req->param('rerferred_by_email'),
                        },                            
                    },
                )->first;
                unless ($referring_player) {
                    return "Can't find the player that referred you. Are you sure you used the correct link?";
                }   
            }
            
            my $verification_code = $c->forward('generate_and_send_verification_code', [$c->req->param('email')] )
                if $c->req->param('email');
            
            my $code;
            if ($c->req->param('promo_code')) {
            	$code = $c->model('DBIC::Promo_Code')->find(
            		{
            			code => $c->req->param('promo_code'),            			
            		},
            		{
            			prefetch => 'promo_org',
            		},            	
            	);
            	
            	if ($code) {
            	    if ($code->uses_remaining > 0) {            		
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
            	    else {
                		$c->flash->{promo_org_message} = $c->forward(
    	                    'RPG::V::TT',
    	                    [
    	                        {
    	                            template      => 'player/promo_used_up_message.html',
    	                            params        => { code => $code, },
    	                            return_output => 1,
    	                        }
    	                    ]
    	                );
                        undef $code;
            	    }
            	}
            }
            
            my $player = $c->model('DBIC::Player')->create(
                {
                    player_name       => $name,
                    email             => $c->req->param('email'),
                    password          => sha1_hex($c->req->param('password1')),
                    verification_code => $verification_code,
                    last_login        => DateTime->now(),
                    $code ? (promo_code_id => $code->code_id) : (),
                    send_email        => $c->req->param('allow_emails') ? 1 : 0,
                    referred_by       => $referring_player ? $referring_player->id : undef,
                    created           => DateTime->now(),
                    last_login        => DateTime->now(),
                    screen_width      => 'auto',
                    screen_height     => 'auto',
                    referer           => $c->session->{referer},
                }
            );
            
            if ($referring_player) {
                # Leave message for referring player's party
                my $party = $referring_player->find_related(
                    'parties',
                    {
                        defunct => undef,
                    }
                );
                
                if ($party) {
                    $party->add_to_messages(
                        {
                            alert_party => 1,
                            day_id => $c->stash->{today}->id,
                            message => "A player you referred - '$name' - has signed up. You'll receive a reward once they've used " .
                                $c->config->{referring_player_turn_threshold} . " turns",
                        }
                    ); 
                }
            }
            
            $c->forward('login_user', [$player]);
            
            $c->res->redirect( $c->config->{url_root} );

            return;
        };
	    if (my $error = $@) {
	        confess $error;
	    }

        return unless $message;
    }
    
    $c->req->param('allow_emails', 0) if $c->req->param('submit') && ! $c->req->param('allow_emails');

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

sub generate_and_send_verification_code : Private {
    my $self       = shift;
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
                    email => $to_address, 
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
		    my $name_to_check = $c->req->param('new_name') || $party->name;
		    
		    # Make sure party to be reformed doesn't have a dupe name
		    my $dupe_party_count = $c->model('DBIC::Party')->search(
                {
                    party_id => {'!=', $party->id },
                    name => $name_to_check,
                    defunct => undef,
                }
            )->count;
                        
            if ($dupe_party_count > 0) {
                $c->forward( 'RPG::V::TT', [ 
                    { 
                        template => 'player/reactivate_dupe_name.html',
                        params => {
                            party_name => $party->name,
                            ($c->req->param('new_name') ? (error => "The new name you've chosen is also taken") : ()),
                        } 
                    } 
                ] );
                return;
            }
		    
		    $party->name($name_to_check);
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
                
                $c->model('DBIC::Player_Login')->create(
                    {
                        ip => $c->req->address,
                        login_date => DateTime->now(),
                        player_id => $player->id,
                        screen_width => $c->req->param('width'),
                        screen_height => $c->req->param('height'),
                    }
                );   
                
                $c->forward('set_screen_size');             

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
		Subject => '[CrownOfConquest] Survey Response',
		Data    => "A survey was completed. The response was:\n\n" . Dumper $survey,
	);
	$msg->send( 'smtp', $c->config->{smtp_server}, Debug => 0, );	
	
	$c->forward( 'RPG::V::TT', [ { template => 'player/survey_thanks.html', } ] );
	
}

sub announcements : Local : Args(1) {
	my ( $self, $c, $is_public ) = @_;
	
	warn $is_public;
	
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
				is_public => $is_public eq 'public' ? 1 : 0,
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
        
        my $vote_date = DateTime->now();
        
        $player_reward_link->last_vote_date($vote_date);
        $player_reward_link->update;
        
        $c->model('DBIC::Player_Reward_Vote')->create(
            {
                player_id => $params{player_id},
                link_id => $link->id,
                vote_date => $vote_date,
            }
        );
        
        my $today = $c->model('DBIC::Day')->find_today;
        
    	$c->model('DBIC::Party_Messages')->create(
    		{
    			message => "You received " . $player_reward_link->link->turn_rewards . " turns for voting for Crown of Conquest at " . $link->label,
    			alert_party => 1,
    			party_id => $party->id,
    			day_id => $today->id,
    		}
    	);
    }    
}

sub submit_bug : Local {
    my ($self, $c) = @_;
    
    $c->forward('submit_email', ['submit_bug']);   
}

sub contact : Local {
    my ($self, $c) = @_;
    
    $c->forward('submit_email', ['contact_us']);   
}

sub submit_email : Private {
    my ($self, $c, $type) = @_;   
    
    my $logged_in = $c->session->{player} ? 1 : 0;
    
    if ($c->req->param('submit') && $c->req->param('subject')) {
        my $email;
        
        my $hs = HTML::Strip->new();
        
        my $body = $hs->parse( $c->req->param('body') );
        
        if (! $logged_in) {
            $email = $c->req->param('email');
            
            if (! $c->validate_captcha( $c->req->param('captcha') )) {
            	$c->detach( 'RPG::V::TT', [ 
            		{ 
            			template => "player/$type.html",
            			fill_in_form => 1,
            			params => {
            			    logged_in => $logged_in,
            			    error => "CAPTCHA code is incorrect!",
            			}
            		},
            	] );                
            }
        }
        else {
            $email = $c->session->{player}->email;               
            
            if ($c->stash->{party}) {
                my $message = $c->model('DBIC::Party_Message')->create(
                    {
                        sender_id => $c->stash->{party}->id,
                        day_id => $c->stash->{today}->id,
                        subject => $c->req->param('subject'),
                        message => $body,
                        type => 'message',
                    }
                );
                
                my $flag = ($type eq 'submit_bug' ? 'bug_manager' : 'contact_manager');
                
                my @recips = $c->model('DBIC::Player')->search(
                    {
                        $flag => 1,   
                    },
                );
                
                foreach my $recip (@recips) {
                    my $party = $recip->find_related(
                        'parties',
                        {
                            defunct => undef,
                        }
                    );
                    
                    $c->model('DBIC::Party_Messages_Recipients')->create(
                        {
                            party_id => $party->id,
                            message_id => $message->id,
                        },
                    );
                }
            }
            
            $body = "Player: " . $c->session->{player}->player_name . "<br><br>" . $body; 
        }        
        
    	my $msg = MIME::Lite->new(
    		From    => $c->config->{send_email_from},
    		To      => $c->config->{send_email_from},
    		'Reply-To' => $email,
    		Subject => "[CrownOfConquest] ($type): " . $c->req->param('subject'),
    		Data    => $body,
    	);
    	$msg->send( 'smtp', $c->config->{smtp_server}, Debug => 0, );        
    	
    	$c->forward( 'RPG::V::TT', [ 
    		{ 
    			template => "player/${type}_thanks.html",
    		} 
    	] );    	
    }
    else {          
    	$c->forward( 'RPG::V::TT', [ 
    		{ 
    			template => "player/$type.html",
    			params => {
    			    logged_in => $logged_in,
    			}
    		},
    	] ); 
    }       
}

sub login_user : Private {
    my ($self, $c, $user) = @_;   
    
    $user->last_login( DateTime->now() );
    
    # Only clear warned for deletion if they're not deleted. Deleted users will get that cleared later
    #  when they reactivate (in Root.pm).
    $user->warned_for_deletion(0) unless $user->deleted;
    $user->update;

    $c->session->{player} = $user;
    $c->session->{partial_login} = 0;
    
    $c->model('DBIC::Player_Login')->create(
        {
            ip => $c->req->address,
            login_date => DateTime->now(),
            player_id => $user->id,
            screen_width => $c->req->param('width'),
            screen_height => $c->req->param('height'),
        }
    );
    
    $c->forward('set_screen_size');
}

sub check_email : Private {
    my ($self, $c, $email) = @_;
    
    return unless $email;
    
    if ( ! Email::Valid->address($email) ) {
        return "The email address '" . $c->req->param('email') . "' does not appear to be valid";  
    }

    my $existing_player = $c->model('DBIC::Player')->find( { email => $email }, );

    if ($existing_player) {
        return $c->forward(
            'RPG::V::TT',
            [
                {
                    template      => 'player/already_exists.html',
                    params        => { email => $email, },
                    return_output => 1,
                }
            ]
        );
    }
    
    return undef;
    
}

sub changelog : Local {
	my ($self, $c) = @_;
	
	$c->forward('RPG::V::TT',
        [{
            template => 'help/ext_changelog.html',
        }]
    );	    
}

1;
