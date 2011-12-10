package RPG::C::Admin::Stats;

use strict;
use warnings;

use base 'Catalyst::Controller';

use Statistics::Basic qw(average);
use RPG::Schema::Creature;
use DateTime;

sub default : Private {
    my ( $self, $c ) = @_;

    $c->forward('logins');
}

sub logins : Local {
    my ( $self, $c ) = @_;
    
    my @counts = $c->model('DBIC::Player_Login')->search(
        {
            login_date => {'>=', DateTime->now()->subtract( months => 1 )},
        },
        {
            select => [ {date => 'login_date', -as => 'date'}, {count => '*', -as => 'count'}],
            as => ['date','count'],
            order_by => 'date desc',
            group_by => 'date',
        }
    );
    
    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'admin/stats/logins.html',
                params   => {
                    counts => \@counts,
                },
            }
        ]
    );    
}

sub regular : Local {
    my ( $self, $c ) = @_;
    
    my $months_ago = $c->req->param('months_ago') // 0;
    
    my @players = $c->model('DBIC::Player_Login')->search(
        {
            login_date => {
                '>=', DateTime->now()->subtract( months => $months_ago + 1 ),
                '<', DateTime->now()->subtract( months => $months_ago )
            },
        },
        {
            'select' => ['player_name', {count => '*', -as => 'count'}],
            'as' => ['player_name', 'count'],
            join => 'player',            
            having => { 'count' => {'>=', $c->req->param('min_logins') // 20} },
            group_by => 'player_name',
            order_by => 'count desc',
        }   
    );
    
    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'admin/stats/players.html',
                params   => {
                    players => \@players,
                    count => scalar @players,
                },
            }
        ]
    );
}

sub new_players : Local {
    my ( $self, $c ) = @_;    
    
    my @players = $c->model('DBIC::Player_Login')->search(
        {
            'player.created' => {'>=', DateTime->now()->subtract( months => 1 )},
        },
        {
            'select' => ['player_name', {count => '*', -as => 'count'}],
            'as' => ['player_name', 'count'],
            join => 'player',
            group_by => 'player_name',
            order_by => 'count desc',
        }   
    );    
    
    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'admin/stats/new_players.html',
                params   => {
                    players => \@players,
                    count => scalar @players,
                },
            }
        ]
    );    
    
}

# XXX: Possibly too slow to run?
sub combat_factors : Local {
    my ( $self, $c ) = @_;

    my $char_rs = $c->model('DBIC::Character')->search(
        { 'party.defunct' => undef, },
        {
            join     => 'party',
            prefetch => 'items',
        }
    );

    my %factors;
    my $max_level = 0;
    while ( my $char = $char_rs->next ) {
        push @{ $factors{ $char->level }{attack_factor} },  $char->attack_factor;
        push @{ $factors{ $char->level }{defence_factor} }, $char->defence_factor;
        push @{ $factors{ $char->level }{damage} },         $char->damage;

        $max_level = $char->level if $max_level < $char->level;
    }

    my %averages;
    my %creature_vals;
    
    for my $level ( 1 .. $max_level ) {
        $averages{$level}{attack_factor}  = average( $factors{$level}{attack_factor} );
        $averages{$level}{defence_factor} = average( $factors{$level}{defence_factor} );
        $averages{$level}{damage}         = average( $factors{$level}{damage} );
    }
    
    my $creature_max_level = $c->model('DBIC::CreatureType')->find(
        {},
        {
            select=>{max=>'level'},
            as=>'max_level',  
        },
    )->get_column('max_level');

    for my $level ( 1 .. $creature_max_level ) {
        $creature_vals{$level}{attack_factor}  = RPG::Schema::Creature->attack_factor($level);
        $creature_vals{$level}{defence_factor} = RPG::Schema::Creature->defence_factor($level);
        $creature_vals{$level}{damage}         = RPG::Schema::Creature->damage($level);
    }

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'admin/stats/combat_factors.html',
                params   => {
                    max_level     => $max_level > $creature_max_level ? $max_level : $creature_max_level,
                    averages      => \%averages,
                    creature_vals => \%creature_vals,
                },
            }
        ]
    );
}

1;
