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
            join     => 'dungeon_room',
        }
    );

    my $map = $c->forward( '/dungeon/render_dungeon_grid', [ \@sectors ] );

    return $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'admin/dungeon/view.html',
                params   => {
                    map => $map,
                },
            }
        ]
    );

}

1;