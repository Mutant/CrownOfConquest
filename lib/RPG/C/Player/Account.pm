package RPG::C::Player::Account;

use strict;
use warnings;

use base 'Catalyst::Controller';

use Digest::SHA1 qw(sha1_hex);

# Note, these may be called by a deleted (yet still logged in player)... so it's not safe to use $c->stash->{party}.

sub change_password : Local {
    my ( $self, $c ) = @_;

    $c->stash->{message_panel_size} = 'large';

    my $message;

    if ( $c->req->param('current_password') ) {
        if ( sha1_hex( $c->req->param('current_password') ) ne $c->session->{player}->password ) {
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

            $player->password( sha1_hex $c->req->param('new_password') );
            $player->update;

            $c->session->{player} = $player;

            $c->stash->{panel_messages} = 'Password changed';

            $c->forward('/party/details/options');
            return;
        }
    }

    $c->forward(
        '/panel/refresh_with_template',
        [
            {
                template => 'player/change_password.html',
                params => { message => $message, },
            }
        ]
    );
}

sub delete_account : Local {
    my ( $self, $c ) = @_;

    $c->session->{delete_account_conf_displayed} = 1;

    $c->forward( 'RPG::V::TT', [ { template => 'player/delete_account.html', } ] );
}

sub delete_account_confirmed : Local {
    my ( $self, $c ) = @_;

    unless ( $c->session->{delete_account_conf_displayed} ) {
        $c->error("Account deletion not confirmed");
        return;
    }

    $c->session->{party_level} = $c->stash->{party}->level;
    $c->session->{turns_used}  = $c->stash->{party}->turns_used;

    my $player = $c->model('DBIC::Player')->find( $c->session->{player}->id );

    my @parties = $player->parties;
    foreach my $party (@parties) {
        next if $party->defunct;
        $party->deactivate;
    }

    $player->delete;
    delete $c->session->{player};

    $c->forward( 'RPG::V::TT', [ { template => 'player/survey.html', } ] );
}

sub disable_tips : Local {
    my ( $self, $c ) = @_;

    my $player = $c->model('DBIC::Player')->find( $c->session->{player}->id );
    $player->display_tip_of_the_day(0);
    $player->update;

    push @{ $c->stash->{panel_messages} }, "Tips of the day disabled";

    $c->forward('/party/main');
}

sub email_unsubscribe : Local {
    my ( $self, $c ) = @_;

    $c->forward( 'RPG::V::TT', [
            {
                template => 'player/email_unsubscribe.html',
                params   => {
                    message => $c->flash->{message},
                  }
            }
    ] );
}

sub disable_emails : Local {
    my ( $self, $c ) = @_;

    my $player = $c->model('DBIC::Player')->find( $c->session->{player}->id );
    $player->send_email(0);
    $player->update;

    $c->flash->{message} = "Email messages disabled";

    $c->res->redirect( $c->config->{url_root} . '/player/account/email_unsubscribe' );
}

sub set_email : Local {
    my ( $self, $c ) = @_;

    my $error = $c->forward( '/player/check_email', [ $c->req->param('email') ] );

    if ($error) {
        $c->stash->{panel_messages} = $error;
    }
    else {
        my $verification_code = $c->forward( '/player/generate_and_send_verification_code', [ $c->req->param('email') ] );

        my $player = $c->model('DBIC::Player')->find( { player_id => $c->session->{player}->id, } );

        $player->email( $c->req->param('email') );
        $player->verification_code($verification_code);
        $player->update;

        $c->session->{player} = $player;

        $c->stash->{panel_messages} = "Email address saved. You will receive an email to allow you to verify your email address. If you "
          . "don't receive it shortly, please check your spam filter";
    }

    $c->forward('/party/details/options');
}

sub reverify : Local {
    my ( $self, $c ) = @_;

    my $message;

    if ( !$c->session->{player}->verified ) {
        my $verification_code = $c->forward( '/player/generate_and_send_verification_code', [ $c->session->{player}->email ] );

        my $player = $c->model('DBIC::Player')->find( { player_id => $c->session->{player}->id, } );

        $player->email( $c->req->param('email') );
        $player->verification_code($verification_code);
        $player->update;

        $c->session->{player} = $player;

        $c->stash->{panel_messages} = "Verification email re-sent. Make sure you check your spam filter!";
    }

    $c->forward('/party/details/options');

}

sub set_town_leave_warning_flag : Local {
    my ( $self, $c ) = @_;

    my $player = $c->model('DBIC::Player')->find( $c->session->{player}->id );
    $player->display_town_leave_warning( $c->req->param('value') eq 'true' ? 1 : 0 );
    $player->update;

    $c->session->{player} = $player;
}

1;
