package RPG::C::Admin::Map;

use strict;
use warnings;

use base 'Catalyst::Controller';

use Data::Dumper;

sub creature : Local {
    my ( $self, $c ) = @_;

    my ( $max_x, $max_y, $grid ) = @{ $c->forward('get_grid') };

    warn Dumper $grid->[1][1];

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'admin/map/creature.html',
                params   => {
                    grid  => $grid,
                    max_x => $max_x,
                    max_y => $max_y,
                },
            }
        ]
    );
}

sub get_grid : Private {
    my ( $self, $c ) = @_;

    my $map = $c->model('DBIC::Land')->get_admin_grid();

    my @grid;
    my $max_x = 0;
    my $max_y = 0;
    foreach my $sector (@$map) {
        $grid[ $sector->{x} ][ $sector->{y} ] = $sector;
        $max_x = $sector->{x} if $sector->{x} > $max_x;
        $max_y = $sector->{y} if $sector->{y} > $max_y;
    }

    return [ $max_x, $max_y, \@grid ];
}

1;
