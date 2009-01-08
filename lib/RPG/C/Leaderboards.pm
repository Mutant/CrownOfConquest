package RPG::C::Leaderboards;

use strict;
use warnings;
use base 'Catalyst::Controller';

sub default : Path {
    my ( $self, $c ) = @_;

    my $sort = $c->req->param('sort') || 'average_xp';

    my @parties = $c->model('DBIC::Party')->search(
        {
            defunct => undef,
            created => { '!=', undef },
        },
        {
            prefetch  => 'player',
            join      => 'characters',
            '+select' => [ \'sum(characters.xp) as total_xp', \'round(avg(characters.xp)) as average_xp', ],
            '+as'     => [ 'total_xp', 'average_xp', ],
            order_by  => $sort . ' desc',
            group_by  => 'party_id',
            rows      => 10,
        },
    );

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'leaderboards/main.html',
                params   => { 
                    parties => \@parties,
                    current_sort => $sort,
                },
            }
        ]
    );
}

1;
