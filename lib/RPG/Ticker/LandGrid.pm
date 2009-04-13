package RPG::Ticker::LandGrid;

use Mouse;

extends 'RPG::Ticker::BaseGrid';

sub BUILD {
    my $self = shift;

    my $land_rs = $self->schema->resultset('Land')->search(
        {},
        {
            join     => [ 'orb',             'creature_group', 'town' ],
            'select' => [ 'creature_threat', 'x',              'y', 'creature_group.creature_group_id', 'town.town_id', 'orb.creature_orb_id' ],
        }
    );

    my $land_by_sector;
    my $max_x        = 0;
    my $max_y        = 0;
    my $sector_count = 0;

    # Could in theory use a HashRefInflator here, but it doesn't seem to load data from joined tables
    my $cursor = $land_rs->cursor;
    while ( my @vals = $cursor->next ) {
        my ( $x, $y ) = ( $vals[1], $vals[2] );

        $land_by_sector->[$x][$y] = {
            orb            => $vals[5] ? 1 : 0,
            creature_group => $vals[3] ? 1 : 0,
            town           => $vals[4] ? 1 : 0,
            ctr            => $vals[0],
            x              => $x,
            y              => $y,
        };
        $max_x = $x if $max_x < $x;
        $max_y = $y if $max_x < $y;
        $sector_count++;
    }

    $self->{land_by_sector} = $land_by_sector;
    $self->max_x($max_x);
    $self->max_y($max_y);
    $self->total_sectors($sector_count);
}

1;
