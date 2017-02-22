use strict;
use warnings;

package Test::RPG::Builder::Treasure_Chest;

sub build_chest {
    my $package = shift;
    my $schema  = shift;
    my %params  = @_;

    my $chest = $schema->resultset('Treasure_Chest')->create(
        {
            dungeon_grid_id => $params{dungeon_grid_id} // 1,
        }
    );

    return $chest;
}

1;
