use strict;
use warnings;

package Test::RPG::Builder::Dungeon_Grid;

sub build_dungeon_grid {
    my $package = shift;
    my $schema  = shift;
    my %params  = @_;

    my $sector = $schema->resultset('Dungeon_Grid')->create(
        {
            x => $params{x},
            y => $params{y},
        }
    );

    my %positions = map { $_->position => $_->position_id  } $schema->resultset('Dungeon_Position')->search();

    if ( ref $params{walls} eq 'ARRAY' ) {
        foreach my $wall ( @{ $params{walls} } ) {
            $schema->resultset('Dungeon_Wall')->create(
                {
                    dungeon_grid_id => $sector->id,
                    position_id     => $positions{$wall},
                }
            );
        }
    }

    if ( ref $params{doors} eq 'ARRAY' ) {
        foreach my $door ( @{ $params{doors} } ) {
            $schema->resultset('Door')->create(
                {
                    dungeon_grid_id => $sector->id,
                    position_id     => $positions{$door},
                }
            );
        }
    }

    return $sector;
}

1;
