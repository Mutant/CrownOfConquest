package RPG::C::Admin::Announcement;

use strict;
use warnings;

use base 'Catalyst::Controller';

use DateTime;

sub default : Path {
    my ( $self, $c ) = @_;

    $c->forward('/admin/announcement/create');
}

sub create : Local {
    my ( $self, $c ) = @_;

    my $preview;
    if ( $c->stash->{preview} ) {
        $preview = $c->forward(
            'RPG::V::TT',
            [
                {
                    template => 'player/announcement/announcement.html',
                    params   => {
                        title        => $c->req->param('title'),
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

    if ( $c->req->param('action') eq 'Preview' ) {
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
            title        => $c->req->param('title'),
            announcement => $c->req->param('announcement'),
            date         => DateTime->now(),
        }
    );

    my @players = $c->model('DBIC::Player')->search();

    foreach my $player (@players) {
        if ( $player->display_announcements ) {
            $c->model('DBIC::Announcement_Player')->create(
                {
                    announcement_id => $announcement->id,
                    player_id       => $player->id,
                    viewed          => 0,
                }
            );
        }
    }

    if ( $c->req->param('email_to') eq 'active' || $c->req->param('email_to') eq 'all' ) {

        my @players_to_email = grep { $_->email && $_->send_email_announcements } @players;

        if ( $c->req->param('email_to') eq 'active' ) {
            @players_to_email = grep { !$_->deleted } @players_to_email;
        }

        $c->log->info( "Sending mail to " . scalar @players_to_email . " players" );

        RPG::Email->send(
            $c->config,
            {
                players => \@players_to_email,
                subject => $c->req->param('title'),
                body    => $c->req->param('announcement'),
            }
        );
    }

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
