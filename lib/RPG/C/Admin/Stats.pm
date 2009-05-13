package RPG::C::Admin::Stats;

use strict;
use warnings;

use base 'Catalyst::Controller';

use Statistics::Basic qw(average);
use RPG::Schema::Creature;

sub default : Private {
    my ( $self, $c ) = @_;

    $c->forward('combat_factors');
}

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
                    max_level     => $max_level,
                    averages      => \%averages,
                    creature_vals => \%creature_vals,
                },
            }
        ]
    );
}

1;
