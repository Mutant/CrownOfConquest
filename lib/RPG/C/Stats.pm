package RPG::C::Stats;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;

sub game : Local {
    my ( $self, $c ) = @_;

    my $players_count = $c->model('DBIC::Player')->search( deleted => 0 )->count;

    my @parties = $c->model('DBIC::Party')->search();

    my $parties_count = grep { !defined $_->defunct } @parties;
    my $defunct_parties_count = scalar @parties - $parties_count;

	my %character_count_clause = (
       	'party.defunct' => undef,
       	'me.party_id' => {'!=', undef},	
	);

    my $character_count_rs = $c->model('DBIC::Character')->find(
      	\%character_count_clause,
        {
            'select' => [          { count => '*' }, { round => { avg => 'level' } } ],
            'as'     => [ 'count', 'average_level' ],
            join     => 'party',
        }
    );

    my $class_rs = $c->model('DBIC::Character')->search(
        \%character_count_clause,
        {
            'select'   => [ 'class.class_name', { count => '*', -as => 'count' } ],
            'as'       => [ 'class_name', 'count' ],
            'join'     => [ 'class',      'party' ],
            'group_by' => 'class_name',
            'order_by' => 'class_name',
        },
    );

    my $race_rs = $c->model('DBIC::Character')->search(
        \%character_count_clause,
        {
            'select'   => [ 'race.race_name',  { count => '*', -as => 'count' } ],
            'as'       => [ 'race_name', 'count' ],
            'join'     => [ 'race',      'party' ],
            'group_by' => 'race_name',
            'order_by' => 'race_name',
        },
    );

    my $cg_count = $c->model('DBIC::CreatureGroup')->search( land_id => { '!=', undef } )->count() || 1;
    

    my $creature_count_rs = $c->model('DBIC::Creature')->find(
        {
            hit_points_current       => { '!=', 0 },
            'creature_group.land_id' => { '!=', undef },
        },
        {
            'select' => [ { count => '*' }, { round => { avg => 'type.level' } } ],
            'as'     => [ 'count', 'average_level' ],
            join     => [ 'type',  'creature_group' ],
        }
    );

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'stats/game.html',
                params   => {
                    players_count               => $players_count,
                    parties_count               => $parties_count,
                    character_count             => $character_count_rs->get_column('count'),
                    average_character_level     => $character_count_rs->get_column('average_level'),
                    class_stats                 => $class_rs,
                    race_stats                  => $race_rs,
                    creature_group_count        => $cg_count,
                    creature_count              => $creature_count_rs->get_column('count'),
                    average_creatures_per_group => int $creature_count_rs->get_column('count') / $cg_count,
                    average_creature_level      => $creature_count_rs->get_column('average_level'),
                },
            }
        ]
    );
}

1;
