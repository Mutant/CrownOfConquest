package RPG::C::Donate;

use strict;
use warnings;
use base 'Catalyst::Controller';

sub default : Path {
    my ($self, $c) = @_;
    
    $c->forward('RPG::V::TT',
        [
            {
                template => 'donate/main.html',
                params => {
                    player => $c->session->{player},
                },
            },
        ]
    );
}

sub thankyou : Path {
    my ($self, $c) = @_;
    
    $c->forward('RPG::V::TT',
        [
            {
                template => 'donate/thankyou.html',
            },
        ]
    )    
}

1;