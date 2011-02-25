package RPG::C::Player::Account;

use strict;
use warnings;

use base 'Catalyst::Controller';

use Digest::SHA1 qw(sha1_hex);

# Note, these may be called by a deleted (yet still logged in player)... so it's not safe to use $c->stash->{party}.

sub change_password : Local {
    my ( $self, $c ) = @_;

    my $message;

    if ( $c->req->param('current_password') ) {
        if ( sha1_hex($c->req->param('current_password')) ne $c->session->{player}->password ) {
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

sub delete_account : Local {
	my ( $self, $c ) = @_;
	
	$c->session->{delete_account_conf_displayed} = 1;
	
    $c->forward( 'RPG::V::TT', [ { template => 'player/delete_account.html', } ] );	
}

sub delete_account_confirmed : Local {
	my ( $self, $c ) = @_;

	unless ($c->session->{delete_account_conf_displayed}) {
		$c->error("Account deletion not confirmed");
		return;	
	}
	
	$c->session->{party_level} = $c->stash->{party}->level;
	$c->session->{turns_used} = $c->stash->{party}->turns;
	
	my $player = $c->model('DBIC::Player')->find( $c->session->{player}->id );
	
	my @parties = $player->parties;
	foreach my $party (@parties) {
		$party->defunct(DateTime->now());
		$party->update;	
	}
	
	$player->delete;
	delete $c->session->{player};
	
    $c->forward( 'RPG::V::TT', [ { template => 'player/survey.html', } ] );	
}

sub disable_tips : Local {
	my ( $self, $c ) = @_;
	
	my $player = $c->model('DBIC::Player')->find( $c->session->{player}->id );;
	$player->display_tip_of_the_day(0);
	$player->update;
	
	push @{$c->stash->{panel_messages}}, "Tips of the day disabled";
	
	$c->forward( '/party/main' );
}

sub email_unsubscribe : Local {
	my ( $self, $c ) = @_;	
	
	$c->forward( 'RPG::V::TT', [ 
		{ 
			template => 'player/email_unsubscribe.html',
			params => {
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

1;