package RPG::Combat::InDungeon;

use Moose::Role;

use List::Util qw(shuffle);
use RPG::Map;

has 'location' => ( is => 'ro', isa => 'RPG::Schema::Dungeon_Grid', required => 0, builder => '_build_location', lazy => 1, );

sub get_sector_to_flee_to {
    my $self = shift;
    my $exclude_creatures //= 0;

    my @sectors_to_flee_to;
    my $range     = 3;
    my $max_range = 10;

    # TODO: refactor to use RowsInSectorRange
    while ( !@sectors_to_flee_to ) {
        my ( $start_point, $end_point ) = RPG::Map->surrounds( $self->location->x, $self->location->y, $range, $range, );

        my %params;
        if ($exclude_creatures) {
            $params{'creature_group.creature_group_id'} = undef;
        }

        my @sectors_in_range = $self->schema->resultset('Dungeon_Grid')->search(
            {
                %params,
                'dungeon_room.dungeon_id' => $self->location->dungeon_room->dungeon_id,
                'x'                       => { '>=', $start_point->{x}, '<=', $end_point->{x}, },
                'y'                       => { '>=', $start_point->{y}, '<=', $end_point->{y}, },
                -nest                     => [
                    'x' => { '!=', $self->location->x },
                    'y' => { '!=', $self->location->y },
                ],
            },
            { join => [ 'creature_group', 'dungeon_room' ] },
        );

        foreach my $sector_in_range (@sectors_in_range) {
            if ( $self->location->has_path_to($sector_in_range->id) ) {
                push @sectors_to_flee_to, $sector_in_range;
            }
        }

        $range++;
        last if $range == $max_range;
    }

    @sectors_to_flee_to = shuffle @sectors_to_flee_to;
    my $land = shift @sectors_to_flee_to;

    confess "Couldn't find land to flee to" unless $land;

    $self->log->debug( "Fleeing to " . $land->x . ", " . $land->y );

    return $land;
}

sub _build_location {
    my $self = shift;

    return $self->schema->resultset('Dungeon_Grid')->find( { dungeon_grid_id => $self->party->dungeon_grid_id, } );
}

sub combat_log_location_attribute {
    return 'dungeon_grid_id';   
}

1;
