package RPG::C::Admin::Stats;

use strict;
use warnings;

use base 'Catalyst::Controller';

use Statistics::Basic qw(average);
use RPG::Schema::Creature;
use DateTime;
use DateTime::Format::MySQL;

sub default : Private {
    my ( $self, $c ) = @_;

    $c->forward('logins');
}

sub daily_stats : Local {
    my ( $self, $c ) = @_;
    
    my @total_login_counts = $c->model('DBIC::Player_Login')->search(
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
    
    my $dbh = $c->model('DBIC')->storage->dbh;
    my $sql = "select date, count(*) as count from (select distinct date(login_date) as date, player_id from Player_Login) pl where date >= ? "
        . " group by date order by date desc";
        
    my $unique_login_counts = $dbh->selectall_arrayref( $sql, { Slice => {} }, DateTime->now()->subtract( months => 1 )->ymd, );
    
    my @registration_counts = $c->model('DBIC::Player')->search(
        {
            created => {'>=', DateTime->now()->subtract( months => 1 )},
        },
        {
            select => [ {date => 'created', -as => 'date'}, {count => '*', -as => 'count'}],
            as => ['date','count'],
            order_by => 'date desc',
            group_by => 'date',
        }
    );    
    
    my @visitors = $c->model('DBIC::Day_Stats')->search(
        {
            date => {'>=', DateTime->now()->subtract( months => 1 )},
        },        
        {
            order_by => 'date desc',
        },
    );     
           
    my @turns_used = $c->model('DBIC::Day')->search(
        {
            date_started => {'>=', DateTime->now()->subtract( months => 1 )},
        },
        {
            order_by => 'date_started desc',
            '+select' => {date => 'date_started', -as => 'date'},
            '+as' => 'date',
        },
    );
    
    my @counts;
    for my $visitor_stats (@visitors) {
        my $date = $visitor_stats->get_column('date');
        
        my %stats = (
            date => $date,
            visitor_count => $visitor_stats->get_column('visitors'),
        );

        my ($total_login_count_rec) = grep { $_->get_column('date') eq $date } @total_login_counts;
        $stats{total_login_count} = $total_login_count_rec && $total_login_count_rec->get_column('count') // 0;
        
        my ($unique_login_count_rec) = grep { $_->{date} eq $date } @$unique_login_counts;
        $stats{unique_login_count} = $unique_login_count_rec && $unique_login_count_rec->{count} // 0;
        
        my ($registrar_count_rec) = grep { $_->get_column('date') eq $date } @registration_counts;
        $stats{registration_count} = $registrar_count_rec && $registrar_count_rec->get_column('count') // 0;
       
        my ($turns_used_rec) = grep { $_->get_column('date') eq $date } @turns_used;
        $stats{turns_used} = $turns_used_rec && $turns_used_rec->turns_used // 0;
        
        if ($stats{visitor_count} != 0) {
            $stats{login_percent} = sprintf '%0.2f', ($stats{total_login_count} / $stats{visitor_count} * 100);
            $stats{reg_percent} = sprintf '%0.2f', ($stats{registration_count} / $stats{visitor_count} * 100);
        
            my $bounced = $stats{visitor_count} - $stats{total_login_count};
            $stats{bounce_percent} = sprintf '%0.2f', ($bounced / $stats{visitor_count} * 100);
        }
        
        $stats{avg_turns} = sprintf '%d', $stats{turns_used} / $stats{total_login_count}
            if $stats{total_login_count} != 0;
        
        push @counts, \%stats;
    }
    
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

sub recent_stickiness : Local {
    my ( $self, $c ) = @_;
    
    my $dbh = $c->model('DBIC')->storage->dbh;
    
    my $sql = "select player_name, created from Player where "
        . "(select count(*) from Player_Login pl where pl.player_id = Player.player_id and login_date > ?) > 0";
        
    my $days_ago = $c->req->param('days_ago') // 7;
        
    my $dt = DateTime->now->subtract( days => $days_ago );
    my $sth = $dbh->prepare($sql);
    $sth->execute($dt->strftime('%F %T'));
    
    my %results;
    my $max_months = 0;
    while (my $data = $sth->fetchrow_hashref) {
        next if $data->{created} eq '0000-00-00 00:00:00';
        
        my $created_dt = DateTime::Format::MySQL->parse_datetime( $data->{created} );
        my $dur = DateTime->now()->subtract_datetime($created_dt);
        
        my $months_ago = $dur->in_units('months');
        $max_months = $months_ago if $months_ago > $max_months;
        
        push @{ $results{$months_ago} }, $data->{player_name};   
    }
    
    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'admin/stats/recent_stickiness.html',
                params   => {
                    results => \%results,
                    months_range => [0..$max_months],
                    days_ago => $days_ago,
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
