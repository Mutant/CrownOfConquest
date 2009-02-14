package RPG::C::Dungeon;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use Carp;

use RPG::Map;

sub admin_view : Local {
    my ( $self, $c ) = @_;

    # XXX temporary
    my $dungeon_id = $c->req->param('dungeon_id');

    my @sectors = $c->model('DBIC::Dungeon_Grid')->search(
        { 'dungeon_room.dungeon_id' => $dungeon_id, },
        {
            prefetch => [ 'doors', 'walls' ],
            join     => 'dungeon_room',
        }
    );

    $c->forward( 'render_dungeon_grid', [ \@sectors ] );

}

sub view : Local {
    my ( $self, $c ) = @_;

    my $current_location = $c->model('DBIC::Dungeon_Grid')->find( { dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, } );
    
    my @mapped_sectors = $c->model('DBIC::Dungeon_Grid')->search(
        {
            party_id => $c->stash->{party}->id,
            'dungeon.dungeon_id' => $current_location->dungeon_room->dungeon_id,
        },
        {
            join => ['mapped_dungeon_grid', {'dungeon_room' => 'dungeon'}],
        }
    );

    my ( $top_corner, $bottom_corner ) = RPG::Map->surrounds_by_range( $current_location->x, $current_location->y, 3 );

    my @sectors = $c->model('DBIC::Dungeon_Grid')->search(
        {
            x               => { '>=', $top_corner->{x}, '<', $bottom_corner->{x} },
            y               => { '>=', $top_corner->{y}, '<', $bottom_corner->{y} },
            dungeon_room_id => $current_location->dungeon_room_id,
        },
        { prefetch => [ 'walls', 'doors' ], },
    );
    
    # Save mapped sectors
    foreach my $sector (@sectors) {
        my $mapped = $c->model('DBIC::Mapped_Dungeon_Grid')->find_or_create(
            party_id => $c->stash->{party}->id,
            dungeon_grid_id => $sector->dungeon_grid_id,
        );
    }

    $c->forward( 'render_dungeon_grid', [ [@sectors, @mapped_sectors], $current_location ] );
}

sub render_dungeon_grid : Private {
    my ( $self, $c, $sectors, $current_location ) = @_;

    my @positions = map { $_->position } $c->model('DBIC::Dungeon_Position')->search;
    
    my $grid;
    my ( $max_x, $max_y ) = ( 0, 0 );

    foreach my $sector (@$sectors) {
        $grid->[ $sector->x ][ $sector->y ] = $sector;

        $max_x = $sector->x if $max_x < $sector->x;
        $max_y = $sector->y if $max_y < $sector->y;
    }

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'dungeon/view.html',
                params   => {
                    grid             => $grid,
                    max_x            => $max_x,
                    max_y            => $max_y,
                    positions        => \@positions,
                    current_location => $current_location,
                },
            }
        ]
    );
}

sub move_to : Local {
    my ( $self, $c, $sector_id ) = @_;

    # TODO: check move is allowed, i.e. not too far from current sector, in correct dungeon, etc.

    $sector_id ||= $c->req->param('sector_id');

    $c->stash->{party}->dungeon_grid_id($sector_id);
    $c->stash->{party}->update;

    $c->res->redirect( $c->config->{url_root} . '/dungeon/view' );
}

sub open_door : Local {
    my ( $self, $c ) = @_;

    # TODO: check door can be opened

    my $door = $c->model('DBIC::Door')->find( $c->req->param('door_id') );

    my ( $opposite_x, $opposite_y ) = $door->opposite_sector;

    my $sector_to_move_to = $c->model('DBIC::Dungeon_Grid')->find(
        {
            x          => $opposite_x,
            y          => $opposite_y,
            'dungeon_room.dungeon_id' => $door->dungeon_grid->dungeon_room->dungeon_id,
        },
        {
            join => 'dungeon_room',
        }
    );

    $c->forward( 'move_to', [ $sector_to_move_to->id ] );
}

1;
