package RPG::C::Player;

use strict;
use warnings;
use base 'Catalyst::Controller';

use MIME::Lite;
use DateTime;
use Carp;

use String::Random;

sub login : Local {
    my ( $self, $c ) = @_;

    my $message;

    if ( $c->req->param('email') ) {
        my $user = $c->model('DBIC::Player')->find( { email => $c->req->param('email'), password => $c->req->param('password'), deleted => 0 } );

        if ($user) {
            $user->last_login( DateTime->now() );
            $user->warned_for_deletion(0);
            $user->update;

            if ( $user->verified ) {
                $c->session->{player} = $user;
                $c->res->redirect( $c->config->{url_root} );
            }
            else {
                $c->res->redirect( $c->config->{url_root} . "/player/verify?email=" . $c->req->param('email') );
            }
        }
        else {
            $message = "Email address and/or password incorrect";
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
        eval {
            unless ( $c->req->param('email')
                && $c->req->param('player_name')
                && $c->req->param('password1')
                && $c->req->param('password1') eq $c->req->param('password2')
                && $c->validate_captcha( $c->req->param('captcha') ) )
            {

                croak { message => "Please enter your email address, name, password and the CAPTCHA code" };

            }

            if ( length $c->req->param('password1') < $c->config->{minimum_password_length} ) {
                croak { message => "Password must be at least " . $c->config->{minimum_password_length} . " characters" };
            }

            my $existing_player = $c->model('DBIC::Player')->find( { email => $c->req->param('email'), deleted => 0 }, );

            if ($existing_player) {
                croak { message => "The email address " . $c->req->param('email') . " has already been registered." };
            }

            my $verification_code = _generate_and_send_verification_code($c, $c->req->param('email'));

            my $player;

            eval {
                $player = $c->model('DBIC::Player')->create(
                    {
                        player_name       => $c->req->param('player_name'),
                        email             => $c->req->param('email'),
                        password          => $c->req->param('password1'),
                        verification_code => $verification_code,
                        last_login        => DateTime->now(),
                    }
                );
            };
            if ($@) {
                if ( $@ =~ /Duplicate entry '.+' for key 2/ ) {
                    croak { message => "A player with the name '" . $c->req->param('player_name') . "' is already registered" };
                }
                else {
                    croak $@;
                }
            }

            $c->res->redirect( $c->config->{url_root} . "/player/verify?email=" . $c->req->param('email') );
        };
    }
    if ($@) {
        my $error = $@;
        if ( ref $error && $error->{message} ) {
            $message = $error->{message};
        }
        else {
            croak $error;
        }
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
    my $c = shift;
    my $to_address = shift;
    
    my $verification_code = ( int rand 100000000 + int rand 100000000 );
    
            my $email_message = $c->forward(
                'RPG::V::TT',
                [
                    {
                        template      => 'player/email/verfication.txt',
                        params        => { verification_code => $verification_code, },
                        return_output => 1,
                    }
                ]
            );

            my $msg = MIME::Lite->new(
                From    => $c->config->{send_email_from},
                To      => $to_address,
                Subject => 'Verification code',
                Data    => $email_message,
            );
            $msg->send( 'smtp', $c->config->{smtp_server}, Debug => 0, );   
            
    return $verification_code;            
}

sub reverify : Local {
    my ( $self, $c ) = @_;    
    
    my $message;
    
    if ( $c->req->param('email') ) {
        $message = eval {
            my $player = $c->model('DBIC::Player')->find({ email => $c->req->param('email'), });
            
            return "Your email address is not registered. Please register first" unless defined $player;
    
            if ($player) {
                if ($player->verified == 1) {
                    return "You're already verified! Please login to play.";   
                }
                
                my $verification_code = _generate_and_send_verification_code($c, $c->req->param('email'));
                
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
    )    
    
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
            
            my $msg = MIME::Lite->new(
                From    => $c->config->{send_email_from},
                To      => $c->req->param('email'),
                Subject => 'Reset Password',
                Data    => $email_message,
            );
            $msg->send(
                'smtp',
                $c->config->{smtp_server},
                AuthUser => $c->config->{smtp_user},
                AuthPass => $c->config->{smtp_pass},
                Debug    => 1,
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

sub change_password : Local {
    my ( $self, $c ) = @_;

    my $message;

    if ( $c->req->param('current_password') ) {
        if ( $c->req->param('current_password') ne $c->session->{player}->password ) {
            $c->stash->{error} = "Current password is incorrect";
        }
        elsif ( $c->req->param('new_password') ne $c->req->param('retyped_password') ) {
            $c->stash->{error} = "New passwords don't match";
        }
        elsif ( length $c->req->param('new_password') < $c->config->{minimum_password_length} ) {
            $c->stash->{error} = "New password must be at least " . $c->config->{minimum_password_length} . " characters";
        }
        else {
            my $player = $c->model('DBIC::Player')->find( { player_id => $c->session->{player}->id, } );

            $player->password( $c->req->param('new_password') );
            $player->update;

            $c->session->{player} = $player;

            $message = 'Password changed';
        }
    }

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'player/change_password.html',
                params   => { message => $message, },
            }
        ]
    );
}

sub verify : Local {
    my ( $self, $c ) = @_;

    my $message;

    if ( $c->req->param('verification_code') ) {
        my $player = $c->model('DBIC::Player')->find({ email => $c->req->param('email'), });

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
    
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'player/about.html',
            }
        ]
    );   
}

1;
