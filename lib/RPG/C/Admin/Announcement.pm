package RPG::C::Admin::Announcement;

use strict;
use warnings;

use base 'Catalyst::Controller';

use MIME::Lite;
use DateTime;

sub default : Path {
    my ( $self, $c ) = @_;

    $c->forward('/admin/announcement/create');
}

sub create : Local {
	my ( $self, $c ) = @_;	
	
	my $preview;
	if ($c->stash->{preview}) {
		$preview = $c->forward(
	        'RPG::V::TT',
	        [
	            {
	                template => 'player/announcement/announcement.html',
	                params   => {
	                	title => $c->req->param('title'),
	                	announcement => $c->req->param('announcement'),
	               	},
	               	return_output => 1,
	            }
	        ]
	    );			
	}
	
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'admin/announcements/announcement.html',
                params   => {
                	preview => $preview,
                },
                fill_in_form => 1,
            }
        ]
    );
}

sub submit : Local {
	my ( $self, $c ) = @_;
	
	if ($c->req->param('action') eq 'Preview') {
		$c->stash->{preview} = 1;
		$c->forward('create');	
	}
	else {
		$c->forward('send');
	}	
}

sub send : Private {
	my ( $self, $c ) = @_;	
	
    unless ( $c->req->param('title') && $c->req->param('announcement') ) {
        $c->stash->{error} = "Please enter a title and an announcement body";
        $c->detach('create');
    }
    
    my $announcement = $c->model('DBIC::Announcement')->create(
    	{
    		title => $c->req->param('title'),
    		announcement => $c->req->param('announcement'),
    		date => DateTime->now(),
    	}
    );

    my @players = $c->model('DBIC::Player')->search( );
    
    foreach my $player (@players) {
    	if ($player->display_announcements) {
	    	$c->model('DBIC::Announcement_Player')->create(
	    		{
	    			announcement_id => $announcement->id,
	    			player_id => $player->id,
	    			viewed => 0,
	    		}
	    	);
    	}
    }

    my $emails = join ', ', ( map { $_->email && $_->send_email_announcements } @players );

=comment
    my $msg = MIME::Lite->new(
        From    => $c->config->{send_email_from},
        Bcc     => $emails,
        Subject => $c->req->param('title'),
        Data    => $c->req->param('announcement'),
        Type    => 'text/html',
    );

    $msg->send( 'smtp', $c->config->{smtp_server}, Debug => 0, );
=cut

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'admin/announcements/confirmation.html',
            }
        ]
    );	
}

1;