package RPG::C::Admin::Dungeon;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use Carp;

use RPG::Map;

sub view : Local {
    my ( $self, $c ) = @_;

    my $dungeon_id = $c->req->param('dungeon_id');

    my @sectors = $c->model('DBIC::Dungeon_Grid')->search(
        { 'dungeon_room.dungeon_id' => $dungeon_id, },
        {
            prefetch => [ 'doors', 'walls' ],
            join => 'dungeon_room',
        }
    );

    my @positions = map { $_->position } $c->model('DBIC::Dungeon_Position')->search;

    my $grid;
    my $max_x;
    my $max_y;
    my $min_x;
    my $min_y;

    foreach my $sector (@sectors) {

        #$c->log->debug( "Rendering: " . $sector->{x} . ", " . $sector->{y} );
        $grid->[ $sector->x ][ $sector->y ] = $sector;

        $max_x = $sector->x if $max_x < $sector->x;
        $max_y = $sector->y if $max_y < $sector->y;
        $min_x = $sector->x if $min_x > $sector->x;
        $min_y = $sector->y if $min_y > $sector->y;
    }

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'admin/dungeon/view.html',
                params   => {
                    grid      => $grid,
                    max_x     => $max_x,
                    max_y     => $max_y,
                    min_x     => $min_x,
                    min_y     => $min_y,
                    positions => \@positions,
                },
            }
        ]
    );

}

1;
