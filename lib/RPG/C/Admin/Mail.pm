package RPG::C::Admin::Mail;

use strict;
use warnings;

use base 'Catalyst::Controller';

use RPG::Email;

sub default : Path {
    my ( $self, $c ) = @_;

    $c->forward('/admin/mail/create');
}

sub create : Local {
    my ( $self, $c ) = @_;

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'admin/mail/create.html',
                params   => {},
            }
        ]
    );
}

sub send : Local {
    my ( $self, $c ) = @_;

    unless ( $c->req->param('subject') && $c->req->param('body') ) {
        $c->stash->{error} = "Please enter a subject and a body";
        $c->detach('create');
    }

    my $message;

    my %params;
    if ( !$c->req->param('active_players') && !$c->req->param('inactive_players') ) {
        $c->stash->{error} = "Must select active or inactive players (or both)";
        $c->detach('create');
    }
    
    if ( $c->req->param('active_players') && !$c->req->param('inactive_players') ) {
        $params{deleted} = 0;
    }
    elsif ( $c->req->param('inactive_players') && !$c->req->param('active_players') ) {
        $params{deleted} = 1;
    }

    if ( !$c->req->param('unverified_players') ) {
        $params{verified} = 1;
    }

    my @players = $c->model('DBIC::Player')->search( \%params );

    RPG::Email->send(
    	$c->config,
    	{
        	players => \@players,
        	subject => $c->req->param('subject'),
        	body    => $c->req->param('body'),
    	}
    );

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'admin/mail/confirmation.html',
                #params   => { emails => $emails, },
            }
        ]
    );
}

1;
