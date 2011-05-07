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
            #prefetch  => ['player'], # For some reason, this breaks the query....
            join      => 'characters',
            '+select' => [ \'sum(characters.xp) as total_xp', \'round(avg(characters.xp)) as average_xp', \'sum(characters.xp)/turns_used as xp_per_turn', \'count(character_id) as character_count' ],
            '+as'     => [ 'total_xp', 'average_xp', 'xp_per_turn', 'character_count' ],
            order_by  => $sort . ' desc',
            group_by  => 'me.party_id',
            rows      => 20,
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

sub kingdoms : Local {
    my ( $self, $c ) = @_;
    
    my @sort_options = qw/total_land town_count party_count/;
    
    my $sort = $c->req->param('sort') || 'total_land';
    
    return unless grep {$_ eq $sort} @sort_options;
    
    my @kingdoms = $c->model('DBIC::Kingdom')->search(
        {
            active => 1,
            'parties.defunct' => undef,
        },
        {
            join => [
                {'sectors' => 'town'},
                'parties',
            ],
            '+select' => [
                { count => 'distinct sectors.land_id', -as => 'total_land' },
                { count => 'distinct town.town_id', -as => 'town_count' },
                { count => 'distinct parties.party_id', -as => 'party_count' },
            ],
            '+as' => [
                'total_land',
                'town_count',
                'party_count',
            ],
            order_by => $sort . ' desc',
            group_by => 'me.kingdom_id',                    
        }
    );
    
    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'leaderboards/kingdoms.html',
                params   => { 
                    kingdoms => \@kingdoms,
                    current_sort => $sort,
                },
            }
        ]
    );
}

1;
