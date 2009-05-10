package RPG::Ticker::DungeonGrid;

use Moose;

# TODO: refactor so we can have some common fuctionality between this and the base grid
#  Main complication is that we need to index everything by dungeon id, as well as x and y
#extends 'RPG::Ticker::BaseGrid';

has 'schema' => ( isa => 'RPG::Schema', is => 'ro', required => 1 );

sub BUILD {
    my $self = shift;

    my $land_rs = $self->schema->resultset('Dungeon_Grid')->search(
        {},
        {
            join     => [ 'creature_group', 'dungeon_room' ],
            'select' => [ 'x',              'y', 'creature_group.creature_group_id', 'dungeon_room.dungeon_id', 'me.dungeon_grid_id' ],
        }
    );

    my $land_by_sector;
    my $max_x;
    my $max_y;

    # Could in theory use a HashRefInflator here, but it doesn't seem to load data from joined tables
    my $cursor = $land_rs->cursor;
    while ( my @vals = $cursor->next ) {
        my ( $x, $y ) = ( $vals[0], $vals[1] );
        my $dungeon_id = $vals[3];

        $land_by_sector->[$dungeon_id][$x][$y] = {
            creature_group => $vals[2] ? 1 : 0,
            x              => $x,
            y              => $y,
            id => $vals[4],
        };
        $max_x->[$dungeon_id] ||= 0;
        $max_y->[$dungeon_id] ||= 0;
        $max_x->[$dungeon_id] = $x if $max_x->[$dungeon_id] < $x;
        $max_y->[$dungeon_id] = $y if $max_y->[$dungeon_id] < $y;
    }

    $self->{land_by_sector} = $land_by_sector;
    $self->{max_x}          = $max_x;
    $self->{max_y}          = $max_y;
}

sub get_land_at_location {
    my $self       = shift;
    my $dungeon_id = shift;
    my $x          = shift;
    my $y          = shift;

    return $self->{land_by_sector}->[$dungeon_id][$x][$y];
}

sub get_sectors_within_range {
    my $self        = shift;
    my $dungeon_id  = shift;
    my $start_point = shift;
    my $end_point   = shift;

    my @sectors;
    for my $x ( $start_point->{x} .. $end_point->{x} ) {
        for my $y ( $start_point->{y} .. $end_point->{y} ) {
            my $sector = $self->get_land_at_location( $dungeon_id, $x, $y );
            push @sectors, $sector if $sector;
        }
    }

    return @sectors;
}

sub get_random_sector_within_range {
    my $self        = shift;
    my $dungeon_id  = shift;
    my $start_point = shift;
    my $end_point   = shift;

    my $x = Games::Dice::Advanced->roll( '1d' . ( $end_point->{x} - $start_point->{x} + 1 ) ) + $start_point->{x} - 1;
    my $y = Games::Dice::Advanced->roll( '1d' . ( $end_point->{y} - $start_point->{y} + 1 ) ) + $start_point->{y} - 1;

    return $self->get_land_at_location( $dungeon_id, $x, $y );
}

sub set_land_object {
    my $self       = shift;
    my $object     = shift;
    my $dungeon_id = shift;
    my $x          = shift;
    my $y          = shift;

    my $sector = $self->get_land_at_location( $dungeon_id, $x, $y );

    $sector->{$object} = 1;
}

sub clear_land_object {
    my $self       = shift;
    my $object     = shift;
    my $dungeon_id = shift;
    my $x          = shift;
    my $y          = shift;

    my $sector = $self->get_land_at_location( $dungeon_id, $x, $y );

    $sector->{$object} = 0;
}

sub max_x {
    my $self       = shift;
    my $dungeon_id = shift;

    return $self->{max_x}->[$dungeon_id];
}

sub max_y {
    my $self       = shift;
    my $dungeon_id = shift;

    return $self->{max_y}->[$dungeon_id];
}

1;
