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

    my @sectors = $c->model('DBIC::Dungeon_Grid')->search( { dungeon_id => $dungeon_id, }, { prefetch => [ 'doors', 'walls' ] } );

    my $grid;
    my ( $max_x, $max_y ) = ( 0, 0 );

    foreach my $sector (@sectors) {
        $grid->[ $sector->x ][ $sector->y ] = $sector;

        $max_x = $sector->x if $max_x < $sector->x;
        $max_y = $sector->y if $max_y < $sector->y;
    }

    $c->forward( 'render_dungeon_grid', [ $grid, $max_x, $max_y ] );

}

sub view : Local {
    my ( $self, $c ) = @_;

    my $current_location = $c->model('DBIC::Dungeon_Grid')->find( { dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, } );

    my ( $top_corner, $bottom_corner ) = RPG::Map->surrounds_by_range( $current_location->x, $current_location->y, 3 );

    my @sectors = $c->model('DBIC::Dungeon_Grid')->search(
        {
            x          => { '>=', $top_corner->{x}, '<', $bottom_corner->{x} },
            y          => { '>=', $top_corner->{y}, '<', $bottom_corner->{y} },
            dungeon_id => $current_location->dungeon_id,
        },
        { prefetch => [ 'walls', 'doors' ], },
    );

    my $grid;
    my ( $min_x, $min_y, $max_x, $max_y ) = ( $sectors[0]->x, $sectors[0]->y, 0, 0 );

    foreach my $sector (@sectors) {
        $grid->[ $sector->x ][ $sector->y ] = $sector;

        $min_x = $sector->x if $min_x > $sector->x;
        $min_y = $sector->y if $min_y > $sector->y;
        $max_x = $sector->x if $max_x < $sector->x;
        $max_y = $sector->y if $max_y < $sector->y;
    }

    # Clear out sectors that can't be seen because of walls
    my @sectors_to_show;
    foreach my $sector (@sectors) {
        if ( my @walls = $sector->sides_with_walls ) {
            foreach my $wall (@walls) {
                if ( $sector->y > $current_location->y && $wall eq 'top' ) {
                    delete $grid->[ $sector->x ][$_] for $sector->y .. $max_y;
                }
                if ( $sector->y < $current_location->y && $wall eq 'bottom' ) {
                    delete $grid->[ $sector->x ][$_] for $min_y .. $sector->y;
                }
                if ( $sector->x > $current_location->x && $wall eq 'left' ) {
                    delete $grid->[$_][ $sector->y ] for $sector->x .. $max_x;
                }
                if ( $sector->x < $current_location->x && $wall eq 'right' ) {
                    delete $grid->[$_][ $sector->y ] for $min_x .. $sector->x;
                }
            }
        }
    }

    $c->forward( 'render_dungeon_grid', [ $grid, $max_x, $max_y, $current_location ] );
}

sub render_dungeon_grid : Private {
    my ( $self, $c, $grid, $max_x, $max_y, $current_location ) = @_;

    my @positions = map { $_->position } $c->model('DBIC::Dungeon_Position')->search;

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
    
    my ($opposite_x, $opposite_y) = $door->opposite_sector;
    
    my $sector_to_move_to = $c->model('DBIC::Dungeon_Grid')->find(
        {
            x => $opposite_x,
            y => $opposite_y,
            dungeon_id => $door->dungeon_grid->dungeon_id,
        },
    );
    
    $c->forward('move_to', [$sector_to_move_to->id]);
}

1;
