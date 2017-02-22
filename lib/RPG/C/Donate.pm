package RPG::C::Donate;

use strict;
use warnings;
use base 'Catalyst::Controller';

sub default : Path {
    my ( $self, $c, $screen ) = @_;

    $c->forward( 'RPG::V::TT',
        [
            {
                template => 'donate/main.html',
                params   => {
                    player => $c->session->{player},
                    screen => $screen,
                },
            },
        ]
    );
}

sub screen {
    my ( $self, $c ) = @_;

    $c->forward( 'default', [1] );
}

sub thankyou : Local {
    my ( $self, $c ) = @_;

    $c->forward( 'RPG::V::TT',
        [
            {
                template => 'donate/thankyou.html',
            },
        ]
      )
}

1;
