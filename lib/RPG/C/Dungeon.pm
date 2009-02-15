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

    my $map = $c->forward( 'render_dungeon_grid', [ \@sectors ] );

    # TODO: display this!

}

sub view : Local {
    my ( $self, $c ) = @_;

    my $current_location = $c->model('DBIC::Dungeon_Grid')->find( { dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, } );

    $c->log->debug( "Current location: " . $current_location->x . ", " . $current_location->y );

    my @mapped_sectors = $c->model('DBIC::Dungeon_Grid')->search(
        {
            party_id             => $c->stash->{party}->id,
            'dungeon.dungeon_id' => $current_location->dungeon_room->dungeon_id,
        },
        {
            join     => 'mapped_dungeon_grid',
            prefetch => [ { 'dungeon_room' => 'dungeon' }, { 'doors' => 'position' }, { 'walls' => 'position' } ],
        }
    );

    my $mapped_sectors_by_coord;
    foreach my $sector (@mapped_sectors) {
        $mapped_sectors_by_coord->[ $sector->x ][ $sector->y ] = $sector;
    }

    my ( $top_corner, $bottom_corner ) = RPG::Map->surrounds_by_range( $current_location->x, $current_location->y, 3 );

    my @sectors = $c->model('DBIC::Dungeon_Grid')->search(
        {
            x                              => { '>=', $top_corner->{x}, '<', $bottom_corner->{x} },
            y                              => { '>=', $top_corner->{y}, '<', $bottom_corner->{y} },
            'dungeon_room.dungeon_room_id' => $current_location->dungeon_room_id,
        },
        { prefetch => [ { 'dungeon_room' => 'dungeon' }, { 'doors' => 'position' }, { 'walls' => 'position' } ], },
    );

    # Save mapped sectors
    foreach my $sector (@sectors) {
        unless ( $mapped_sectors_by_coord->[ $sector->x ][ $sector->y ] ) {
            my $mapped = $c->model('DBIC::Mapped_Dungeon_Grid')->create(
                {
                    party_id        => $c->stash->{party}->id,
                    dungeon_grid_id => $sector->dungeon_grid_id,
                }
            );
        }
    }

    return $c->forward( 'render_dungeon_grid', [ [ @sectors, @mapped_sectors ], $current_location ] );
}

sub render_dungeon_grid : Private {
    my ( $self, $c, $sectors, $current_location ) = @_;

    my @positions = map { $_->position } $c->model('DBIC::Dungeon_Position')->search;

    my $grid;
    my ( $min_x, $min_y, $max_x, $max_y ) = ( $sectors->[0]->x, $sectors->[0]->y, 0, 0 );

    foreach my $sector (@$sectors) {
        #$c->log->debug( "Rendering: " . $sector->x . ", " . $sector->y );
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
                template => 'dungeon/view.html',
                params   => {
                    grid             => $grid,
                    max_x            => $max_x,
                    max_y            => $max_y,
                    min_x            => $min_x,
                    min_y            => $min_y,
                    positions        => \@positions,
                    current_location => $current_location,
                },
                return_output => 1,
            }
        ]
    );
}

sub move_to : Local {
    my ( $self, $c, $sector_id ) = @_;

    $sector_id ||= $c->req->param('sector_id');

    my $current_location =
        $c->model('DBIC::Dungeon_Grid')->find( { dungeon_grid_id => $c->stash->{party}->dungeon_grid_id, }, { prefetch => 'dungeon_room', } );

    my $sector = $c->model('DBIC::Dungeon_Grid')->find( { 'dungeon_grid_id' => $sector_id, }, { prefetch => 'dungeon_room', } );

    croak "Can't find sector: $sector_id" unless $sector;

    # Check they're moving to a sector in the dungeon they're currently in
    if ( $current_location->dungeon_room->dungeon_id != $current_location->dungeon_room->dungeon_id ) {
        croak "Can't move to sector: $sector_id - in the wrong dungeon";
    }

    # Check they're allowed to move to this sector
    unless ( $current_location->allowed_to_move_to_sector($sector) ) {
        $c->stash->{error} = "You must be in range of the door before opening it";
    }
    elsif ( $c->stash->{party}->turns < 1 ) {
        $c->stash->{error} = "You do not have enough turns to move there";
    }
    else {
        $c->stash->{party}->dungeon_grid_id($sector_id);
        $c->stash->{party}->turns( $c->stash->{party}->turns - 1 );
        $c->stash->{party}->update;
    }

    $c->forward( '/panel/refresh', [ 'map', 'messages', 'party_status' ] );
}

sub open_door : Local {
    my ( $self, $c ) = @_;

    # TODO: check door can be opened

    my $door = $c->model('DBIC::Door')->find( $c->req->param('door_id') );

    my ( $opposite_x, $opposite_y ) = $door->opposite_sector;

    $c->log->debug("Opening door, and moving to sector: $opposite_x, $opposite_y");

    my $sector_to_move_to = $c->model('DBIC::Dungeon_Grid')->find(
        {
            x                         => $opposite_x,
            y                         => $opposite_y,
            'dungeon_room.dungeon_id' => $door->dungeon_grid->dungeon_room->dungeon_id,
        },
        { join => 'dungeon_room', }
    );

    $c->forward( 'move_to', [ $sector_to_move_to->id ] );
}

1;
