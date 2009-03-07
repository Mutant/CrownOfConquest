package RPG::C::Admin::Mail;

use strict;
use warnings;

use base 'Catalyst::Controller';

use MIME::Lite;

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

    my @players = $c->model('DBIC::Player')->search;

    my $emails = join ', ', ( map { $_->email } @players );

    my $msg = MIME::Lite->new(
        From    => $c->config->{send_email_from},
        Bcc     => $emails,
        Subject => $c->req->param('subject'),
        Data    => $c->req->param('body'),
    );

    $msg->send(
        'smtp',
        $c->config->{smtp_server},
        Debug    => 1,
    );

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'admin/mail/confirmation.html',
                params   => {
                    emails => $emails,
                },
            }
        ]
    );
}

1;
