use strict;
use warnings;

package Test::RPG::Builder::Land;

sub build_land {
    my $self   = shift;
    my $schema = shift;
    my %params = @_;

    my $terrain = $schema->resultset('Terrain')->create( { terrain_name => 'terrain', modifier => 5 } );

    my %x_y_range = $schema->resultset('Land')->get_x_y_range();

    my $start_x = $x_y_range{max_x} + 1;
    my $start_y = $x_y_range{max_y} + 1;
    my $end_x   = $start_x + ($params{'x_size'} || 3) -1;
    my $end_y   = $start_y + ($params{'y_size'} || 3) -1;

    my @land;
    for my $x ( $start_x .. $end_x ) {
        for my $y ( $start_y .. $end_y ) {
            push @land, $schema->resultset('Land')->create(
                {
                    x               => $x,
                    y               => $y,
                    terrain_id      => $terrain->id,
                    creature_threat => 10,
                    kingdom_id      => $params{kingdom_id},
                    tileset_id      => 1,
                }
            );
        }
    }

    return @land;
}

1;
