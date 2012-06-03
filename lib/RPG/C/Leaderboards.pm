package RPG::C::Leaderboards;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Math::Round qw(round);

sub default : Path {
    my ( $self, $c ) = @_;

    my @sort_options = qw/average_xp total_xp turns_used xp_per_turn/;
    
    my $sort = $c->req->param('sort') || 'xp_per_turn';
    
    return unless grep {$_ eq $sort} @sort_options;
    
    my $page = $c->req->param('page') || 1;    

    my $party_count = $c->model('DBIC::Party')->search(
        {
            defunct => undef,
            created => { '!=', undef },
        },
    )->count;
    
    my $page_count = $party_count / $c->config->{leaderboard_page_size};
    $page_count = int $page_count + 1 if $page_count =~ /\./; 
    $page = $page_count if $page > $page_count;
    
    my $offset = ($page - 1) * $c->config->{leaderboard_page_size};
    
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
            order_by  => $sort . ' desc, created',
            group_by  => 'me.party_id',
            rows      => $c->config->{leaderboard_page_size},
            offset    => $offset,
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
                    current_page => $page,
                    page_count => $page_count,
                    offset => $offset,
                },
            }
        ]
    );
}

sub kingdoms : Local {
    my ( $self, $c ) = @_;
    
    my @sort_options = qw/majesty total_land town_count party_count/;
    
    my $sort = $c->req->param('sort') || 'majesty';
    
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
