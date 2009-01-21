package RPG::C::Leaderboards;

use strict;
use warnings;
use base 'Catalyst::Controller';

sub default : Path {
    my ( $self, $c ) = @_;

    my @sort_options = qw/average_xp total_xp turns_used xp_per_turn/;
    
    my $sort = $c->req->param('sort') || 'xp_per_turn';
    
    return unless grep {$_ eq $sort} @sort_options;    

    my @parties = $c->model('DBIC::Party')->search(
        {
            defunct => undef,
            created => { '!=', undef },
        },
        {
            prefetch  => ['player'],
            join      => 'characters',
            '+select' => [ \'sum(characters.xp) as total_xp', \'round(avg(characters.xp)) as average_xp', \'sum(characters.xp)/turns_used as xp_per_turn', \'count(character_id) as character_count' ],
            '+as'     => [ 'total_xp', 'average_xp', 'xp_per_turn', 'character_count' ],
            order_by  => $sort . ' desc',
            group_by  => 'me.party_id',
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
