package RPG::C::Root;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use RPG::Schema;
use Carp qw(cluck);

use DateTime;
use DateTime::Format::HTTP;

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in RPG.pm
#
__PACKAGE__->config->{namespace} = '';

# List of paths where players can use a 'partial login', i.e. an email hash
#  Also skips reactivation check
# Mostly used so they can log in, change some settings, and log out, without having to worry about playing the game
my @PARTIAL_LOGIN_ALLOWED_PATHS = (
	'player/account/email_unsubscribe',
	'player/account/disable_emails',
);

# These paths skip the check for an activated party (but still require a login)
my @ACTIVATION_NOT_REQUIRED_PATHS = qw(
	player/account/delete_account
	player/account/delete_account_confirmed
);

sub auto : Private {
    my ( $self, $c ) = @_;

    $c->req->base( $c->config->{url_root} );

    $c->model('DBIC')->schema->config( RPG->config );
    
    $c->model('DBIC')->schema->log( $c->log );

    $c->model('DBIC')->storage->txn_begin;
    
    # If they have a 'partial' login, check they're accessing one of the allowed paths
    my $allowed_partial_login = 0;
    if ($c->session->{partial_login} && $c->action ~~ \@PARTIAL_LOGIN_ALLOWED_PATHS) {
        $allowed_partial_login = 1;   
    }    

    $c->stash->{today} = $c->model('DBIC::Day')->find_today;

    if ( !$c->session->{player} || ($c->session->{partial_login} && ! $allowed_partial_login) ) {
        if ( $c->action !~ m|^player(?!/account)| && $c->action !~ m|^donate| ) {
            $c->detach('/player/login');
        }
        return 1;
    }
        
    return 1 if $c->action =~ m/^admin/;
    
    $c->forward('check_for_deleted_player') unless $allowed_partial_login;

    $c->stash->{party} = $c->model('DBIC::Party')->get_by_player_id( $c->session->{player}->id );

    if ( $c->stash->{party} && $c->stash->{party}->created ) {
        
        # Display announcements if relevant
        if ($c->session->{announcements}) {
        	$c->forward('display_announcements');	
        }
        
        # Display tip of the day, if necessary
        if ($c->flash->{tip} && ! $c->stash->{party}->in_combat_with) {
        	$c->forward('display_tip_of_the_day');
        }

        $c->stash->{party_location} = $c->stash->{party}->location;

    }
    elsif ( $c->action !~ m|^party/create| && $c->action !~ m|^help| && $c->action ne 'player/logout' && $c->action ne 'player/reactivate' ) {
       	$c->res->redirect( $c->config->{url_root} . '/party/create/create' );
       	return 0;
    }
    
    $c->log->debug("End of /auto");

    return 1;

}

sub check_for_deleted_player : Private {
	my ($self, $c) = @_;
		
	if ($c->session->{player}->deleted) {
	    return if $c->action ~~ \@ACTIVATION_NOT_REQUIRED_PATHS;
	    
		# Check for a full game
		my $players_in_game_rs = $c->model('DBIC::Player')->search( { deleted => 0 } );
		if ( $players_in_game_rs->count > $c->config->{max_number_of_players} ) {
			
			$c->log->debug("Player deleted, but game is full");

            $c->detach( 'RPG::V::TT', [ 
            	{
                    template => 'player/full.html', 
                    params => { inactive => 1 } 
                } 
             ]);
        }
        
        $c->log->debug("Undeleting player: " . $c->session->{player}->id);
        
        my $player = $c->model('DBIC::Player')->find($c->session->{player}->id);
                
        $player->deleted(0);
        $player->warned_for_deletion(0);
        $player->update;
        
        $c->session->{player} = $player;
         
        $c->detach( "/player/reactivate" );
	}	
}

sub display_announcements : Private {
    my ( $self, $c ) = @_;
    
    my $announcement_to_display = $c->session->{announcements}->[0];
    
    # Mark announcements as viewed by this player
    foreach my $announcement (@{ $c->session->{announcements}}) {
    	$c->model('DBIC::Announcement_Player')->find(
			{
    		   	announcement_id => $announcement->id,
    			player_id => $c->session->{player}->id,
    		},
    	)->update(
    		{
    			viewed => 1,
    		},
    	);
    }
    
    push @{ $c->stash->{panel_messages} }, $c->forward(
	    'RPG::V::TT',
        [
    	    {
        	    template      => 'player/announcement/login_message.html',
                params        => { 
                	announcement => $announcement_to_display,
                	announcement_count => scalar @{ $c->session->{announcements}},
                },
                return_output => 1,
            }
        ]
   );
   
   $c->session->{announcements} = undef;
}

sub display_tip_of_the_day : Private {
    my ( $self, $c ) = @_;	
    
    my $tip = $c->flash->{tip};
    
    push @{ $c->stash->{panel_messages} }, $c->forward(
	    'RPG::V::TT',
        [
    	    {
        	    template      => 'player/tip_of_the_day.html',
                params        => { 
                	tip => $tip,
                },
                return_output => 1,
            }
        ]
   );    
}

sub default : Private {
    my ( $self, $c ) = @_;

    $c->forward('/party/main');
}

sub end : Private {
    my ( $self, $c ) = @_;

    if ( $c->stash->{party} && ! $c->stash->{dont_update_last_action} ) {
        $c->stash->{party}->last_action( DateTime->now() );
        $c->stash->{party}->update;
    }

    $c->response->headers->header( 'Expires'       => DateTime::Format::HTTP->format_datetime( DateTime->now() ) );
    $c->response->headers->header( 'Cache-Control' => 'max-age=0, must-revalidate' );

    if ( scalar @{ $c->error } ) {

        # Log error message
        $c->log->error('An error occured...');
        $c->log->error( "Action: " . $c->action );
        $c->log->error( "Path: " . $c->req->path );
        $c->log->error( "Params: " . Dumper $c->req->params );
        $c->log->error( "Player: " . $c->session->{player}->id ) if $c->session->{player};
        $c->log->error( "Party: " . $c->stash->{party}->id )     if $c->stash->{party};
        foreach my $err_str ( @{ $c->error } ) {
            $c->log->error($err_str);
        }

        $c->model('DBIC')->storage->txn_rollback;

        #$dbh->rollback unless $dbh->{AutoCommit};

        # Display error page
        $c->forward(
            'RPG::V::TT',
            [
                {
                    template => 'error.html',
                }
            ]
        );

        $c->error(0);
    }
    else {
        $c->model('DBIC')->storage->txn_commit;

        #$dbh->commit unless $dbh->{AutoCommit};
    }

    return 1 if $c->response->status =~ /^3\d\d$/;
    return 1 if $c->response->body;

    unless ( $c->response->content_type ) {
        $c->response->content_type('text/html; charset=utf-8');
    }
}

1;
