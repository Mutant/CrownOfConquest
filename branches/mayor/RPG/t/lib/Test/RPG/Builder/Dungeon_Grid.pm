use strict;
use warnings;

package Test::RPG::Builder::Dungeon_Grid;

use Data::Dumper;

sub build_dungeon_grid {
    my $package = shift;
    my $schema  = shift;
    my %params  = @_;

    my $sector = $schema->resultset('Dungeon_Grid')->create(
        {
            x => $params{x} || 1,
            y => $params{y} || 1,
            dungeon_room_id => $params{dungeon_room_id} || 1,
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
            my %door_params;
            
            if (ref $door eq 'HASH') {
                %door_params = (
                    type => $door->{type},
                    state => $door->{state},
                    position_id => $positions{$door->{position}},
                );   
            }
            else {
                $door_params{position_id} = $positions{$door};
            }            
            
            $schema->resultset('Door')->create(
                {
                    dungeon_grid_id => $sector->id,
                    %door_params,
                }
            );
        }
    }

    return $sector;
}

1;
