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
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

sub auto : Private {
    my ( $self, $c ) = @_;

    $c->req->base( $c->config->{url_root} );

    $c->model('DBIC')->schema->config( RPG->config );
    
    $c->model('DBIC')->schema->log( $c->log );

    $c->model('DBIC')->storage->txn_begin;

    if ( !$c->session->{player} ) {
        if ( $c->action !~ m|^player| ) {
            $c->detach('/player/login');
        }
        return 1;
    }

    return 1 if $c->action =~ m/^admin/;

    $c->stash->{party} = $c->model('DBIC::Party')->get_by_player_id( $c->session->{player}->id );

    $c->stash->{today} = $c->model('DBIC::Day')->find(
        {},
        {
            'rows'     => 1,
            'order_by' => 'day_number desc'
        },
    );

    if ( $c->stash->{party} && $c->stash->{party}->created ) {

        # Get recent combat count if party has been offline
        # (We check $c->flash->{fresh_login} first to ensure this is only done immediately after login)
        if ( $c->stash->{party}->last_action <= DateTime->now()->subtract( minutes => $c->config->{online_threshold} ) ) {
            my $offline_combat_count = $c->model('DBIC::Combat_Log')->get_offline_log_count( $c->stash->{party} );
            if ( $offline_combat_count > 0 ) {
                push @{ $c->stash->{messages} }, $c->forward(
                    'RPG::V::TT',
                    [
                        {
                            template      => 'party/offline_combat_message.html',
                            params        => { offline_combat_count => $offline_combat_count },
                            return_output => 1,
                        }
                    ]
                );
            }
        }
        
        # Display announcements if relevant
        if ($c->session->{announcements}) {
        	$c->forward('display_announcements');	
        }
        
        # Display tip of the day, if necessary
        if ($c->flash->{tip} && ! $c->stash->{party}->in_combat_with) {
        	$c->forward('display_tip_of_the_day');
        }

        $c->stash->{party_location} = $c->stash->{party}->location;

        # Get parties online
        my @parties_online = $c->model('DBIC::Party')->search(
            {
                last_action => { '>=', DateTime->now()->subtract( minutes => $c->config->{online_threshold} ) },
                defunct     => undef,
                name => { '!=', '' },
            }
        );
        $c->stash->{parties_online} = \@parties_online;

        # If the party is currently in combat, they must stay on the combat screen
        # TODO: clean up this logic!
        if (   $c->stash->{party}->in_combat
            && $c->action ne 'party/main'
            && $c->action !~ m{^((dungeon|party)/)?combat}
            && $c->action ne 'party/select_action'
            && $c->action ne 'default'
            && $c->action ne 'player/logout' )
        {
            $c->debug('Forwarding to /party/main since party is in combat');
            $c->stash->{error} = "You must flee before trying to move away!";
            $c->forward('/party/main');
            return 0;
        }
    }
    elsif ( $c->action !~ m|^party/create| && $c->action !~ m|^help| && $c->action ne 'player/logout' && $c->action ne 'player/reactivate' ) {
        $c->res->redirect( $c->config->{url_root} . '/party/create/create' );
        return 0;
    }

    return 1;

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

    if ( $c->stash->{party} ) {
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
                    params   => { error_msgs => $c->error, },
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
