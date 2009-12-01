use strict;
use warnings;

package Test::RPG::Builder::Land;

sub build_land {
    my $self   = shift;
    my $schema = shift;
    my %params = @_;

    my $terrain = $schema->resultset('Terrain')->create( { terrain_name => 'terrain', modifier => 5} );

    my @land;
    for my $x ( 1 .. ($params{x_size} || 3) ) {
        for my $y ( 1 .. ($params{'y_size'} || 3) ) {
            push @land, $schema->resultset('Land')->create(
                {
                    x               => $x,
                    y               => $y,
                    terrain_id      => $terrain->id,
                    creature_threat => 10,
                }
            );
        }
    }

    return @land;
}

1;