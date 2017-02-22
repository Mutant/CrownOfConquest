package RPG::C::Admin::Parties;

use strict;
use warnings;
use base 'Catalyst::Controller';

sub default : Path {
    my ( $self, $c ) = @_;

    my @parties = $c->model('DBIC::Party')->search(
        {
            defunct => undef,
        },
        {
            order_by => 'last_action desc',
        },
    );

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'admin/parties/main.html',
                params   => {
                    parties => \@parties,
                },
            }
        ]
    );
}

1;
