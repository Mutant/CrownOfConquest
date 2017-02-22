use strict;
use warnings;

package Test::RPG::NewDay::Dungeon::Paths;

use base qw(Test::RPG::NewDay::Dungeon::Base);

__PACKAGE__->runtests unless caller();

use Carp qw(confess);
use Data::Dumper;

use Test::MockObject;
use Test::More;
use Test::Exception;

use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Dungeon_Room;
use Test::RPG::Builder::Dungeon_Grid;

# Override parent class's setup method
sub dungeon_setup : Tests(setup) {
    my $self = shift;

    $self->{dungeon} = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );

}

sub test_can_move_to : Test(44) {
    my $self = shift;

    # GIVEN
    my %tests = (
        'no_walls_or_doors' => {
            first_sector => {
                x => 1,
                y => 1,
            },
            second_sector => {
                x => 2,
                y => 1,
            },
            expected_result        => 1,
            expected_doors_in_path => [],
        },

        'sectors_not_adjacent' => {
            first_sector => {
                x => 1,
                y => 1,
            },
            second_sector => {
                x => 3,
                y => 1,
            },
            expected_result => 0,
        },

        'move_blocked_by_wall' => {
            first_sector => {
                x     => 1,
                y     => 1,
                walls => ['bottom'],
            },
            second_sector => {
                x     => 1,
                y     => 2,
                walls => ['top'],
            },
            expected_result => 0,
        },

        'wall_and_door_between_sector' => {
            first_sector => {
                x     => 1,
                y     => 1,
                walls => ['bottom'],
                doors => ['bottom'],
            },
            second_sector => {
                x     => 1,
                y     => 2,
                walls => ['top'],
                doors => ['top'],
            },
            expected_result        => 1,
            expected_doors_in_path => ['bottom'],
        },

        'walls_in_dest_block_diagonal_move' => {
            first_sector => {
                x => 2,
                y => 2,
            },
            second_sector => {
                x     => 1,
                y     => 1,
                walls => [ 'bottom', 'right' ],
            },
            expected_result => 0,
        },

        'walls_at_start_block_diagonal_move' => {
            first_sector => {
                x     => 2,
                y     => 2,
                walls => [ 'left', 'top' ],
            },
            second_sector => {
                x => 1,
                y => 1,
            },
            expected_result => 0,
        },

        'walls_dont_block_diagonal_move' => {
            first_sector => {
                x => 1,
                y => 3,
            },
            second_sector => {
                x     => 2,
                y     => 2,
                walls => ['right'],
            },
            expected_result        => 1,
            expected_doors_in_path => [],
        },

        'walls_block_diagonal_move_but_door_allows_movement' => {
            first_sector => {
                x     => 1,
                y     => 1,
                walls => [ 'bottom', 'right' ],
                doors => ['right'],
            },
            second_sector => {
                x => 2,
                y => 2,
            },
            expected_result        => 1,
            expected_doors_in_path => ['right'],
        },

        'wall_and_door_between_diagonal_but_door_allows_movement' => {
            first_sector => {
                x     => 1,
                y     => 1,
                walls => ['bottom'],
            },
            second_sector => {
                x     => 2,
                y     => 2,
                walls => ['top'],
                doors => ['top'],
            },
            expected_result        => 1,
            expected_doors_in_path => ['top'],
        },

        'walls_block_diagonal_even_though_doors_exist' => {
            first_sector => {
                x     => 2,
                y     => 2,
                walls => ['left'],
            },
            second_sector => {
                x     => 1,
                y     => 1,
                walls => [ 'bottom', 'right' ],
                doors => ['bottom'],
            },
            expected_result => 0,
        },

        'walls_in_dest_block_diagonal_move_to_top_right' => {
            first_sector => {
                x     => 1,
                y     => 3,
                walls => [ 'top', 'right' ],
            },
            second_sector => {
                x => 2,
                y => 2,

            },
            expected_result => 0,
        },

        'verticle_in_line_walls_block_diagonal_move_to_bottom_right' => {
            first_sector => {
                x     => 1,
                y     => 1,
                walls => ['right'],
            },
            second_sector => {
                x     => 2,
                y     => 2,
                walls => ['left'],

            },
            expected_result => 0,
        },

        'horizontal_in_line_walls_block_diagonal_move_to_bottom_right' => {
            first_sector => {
                x     => 1,
                y     => 1,
                walls => ['bottom'],
            },
            second_sector => {
                x     => 2,
                y     => 2,
                walls => ['top'],

            },
            expected_result => 0,
        },

        'horizontal_wall_blocks_but_door_allows_diagonal_move_to_bottom_right' => {
            first_sector => {
                x     => 1,
                y     => 1,
                walls => ['bottom'],
                doors => ['bottom'],
            },
            second_sector => {
                x     => 2,
                y     => 2,
                walls => ['top'],

            },
            expected_result        => 1,
            expected_doors_in_path => ['bottom'],
        },

        'stuck_door_blocks_path' => {
            first_sector => {
                x     => 1,
                y     => 1,
                walls => ['bottom'],
                doors => [ {
                        position => 'bottom',
                        type     => 'stuck',
                        state    => 'closed',
                    } ],
            },
            second_sector => {
                x     => 1,
                y     => 2,
                walls => ['top'],
            },
            expected_result        => 1,
            expected_doors_in_path => ['bottom'],
        },
    );

    # WHEN
    my %results;
    while ( my ( $test_name, $test_data ) = each %tests ) {
        my $first_sector = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid( $self->{schema}, %{ $test_data->{first_sector} } );
        my $second_sector = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid( $self->{schema}, %{ $test_data->{second_sector} } );

        $results{$test_name} = $self->{dungeon}->can_move_to( $first_sector, $second_sector );
    }

    # THEN
    while ( my ( $test_name, $test_data ) = each %tests ) {
        is( $results{$test_name}->{has_path}, $test_data->{expected_result}, "$test_name: Got expected has_path result" );

        my $doors_in_path_results = $results{$test_name}->{doors_in_path};

        if ( $test_data->{expected_doors_in_path} ) {

            is( ref $doors_in_path_results, 'ARRAY', "$test_name: Array of doors in path returned" );

            is( scalar @$doors_in_path_results, scalar @{ $test_data->{expected_doors_in_path} }, "$test_name: Correct number of doors in path" );

            my @door_position_results = map { $_->position->position } @$doors_in_path_results;

            # TODO: this should really check not just the positions, but that the sector is correct
            is_deeply( [ sort(@door_position_results) ], [ sort( @{ $test_data->{expected_doors_in_path} } ) ], "$test_name: Expected doors in path returned" );
        }
        else {
            is( $doors_in_path_results, undef, "$test_name: No doors in path returned" )
              or diag "has " . scalar @$doors_in_path_results . " doors";
        }
    }

}

sub check_has_path_simple : Tests(1) {
    my $self = shift;

    # GIVEN
    my $sector_grid;
    for my $x ( 1 .. 3 ) {
        for my $y ( 1 .. 3 ) {
            my $sector = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid(
                $self->{schema},
                x => $x,
                y => $y,
            );
            $sector_grid->[$x][$y] = $sector;
        }
    }

    # WHEN
    my $result = $self->{dungeon}->check_has_path( $sector_grid->[1][1], $sector_grid->[3][3], $sector_grid, 2 );

    is( $result->{has_path}, 1, "Path found, as nothing blocking sectors" );
}

sub check_has_path_path_blocked : Tests(1) {
    my $self = shift;

    # GIVEN
    my $sector_grid;
    for my $x ( 1 .. 3 ) {
        for my $y ( 1 .. 3 ) {
            my @walls;

            if ( $x == 1 && $y == 1 ) {
                @walls = ( 'bottom', 'right' );
            }

            my $sector = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid(
                $self->{schema},
                x     => $x,
                y     => $y,
                walls => \@walls,
            );
            $sector_grid->[$x][$y] = $sector;
        }
    }

    # WHEN
    my $result = $self->{dungeon}->check_has_path( $sector_grid->[1][1], $sector_grid->[3][3], $sector_grid, 2 );

    # THEN
    is( $result->{has_path}, 0, "Path not found, as wall blocks destination" );
}

sub check_has_path_walls_force_longer_path : Tests(9) {
    my $self = shift;

    # GIVEN
    my $sector_grid;
    for my $x ( 1 .. 3 ) {
        for my $y ( 1 .. 3 ) {
            my @walls;
            my @doors;

            if ( $x == 2 && $y == 1 ) {
                @walls = ( 'bottom', 'left' );
            }
            if ( $x == 2 && $y == 2 ) {
                @walls = ('top');
            }
            if ( $x == 3 && $y == 1 ) {
                @walls = ( 'bottom', 'right' );
                @doors = ('bottom');
            }
            if ( $x == 3 && $y == 2 ) {
                @walls = ('top');
                @doors = ('top');
            }

            my $sector = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid(
                $self->{schema},
                x     => $x,
                y     => $y,
                walls => \@walls,
                doors => \@doors,
            );
            $sector_grid->[$x][$y] = $sector;
        }
    }

    # WHEN
    my $move_up_result = $self->{dungeon}->check_has_path( $sector_grid->[2][2], $sector_grid->[2][1], $sector_grid, 1 );
    my $move_top_right_result = $self->{dungeon}->check_has_path( $sector_grid->[2][2], $sector_grid->[3][1], $sector_grid, 1 );
    my $move_up_result_longer_path = $self->{dungeon}->check_has_path( $sector_grid->[2][2], $sector_grid->[2][1], $sector_grid, 2 );

    # THEN
    is( $move_up_result->{has_path}, 0, "Couldn't move up, as path too long (via door)" );

    is( $move_top_right_result->{has_path}, 1, "Could move to top right via door" );
    is( scalar @{ $move_top_right_result->{doors_in_path} }, 1, "1 Door in path returned" );
    is( $move_top_right_result->{doors_in_path}[0]->position->position, 'bottom', "Door in path returned, correct position" );
    is( $move_top_right_result->{doors_in_path}[0]->dungeon_grid_id, $sector_grid->[3][1]->id, "Door in path returned, correct sector" );

    is( $move_up_result_longer_path->{has_path}, 1, "Could move up when longer move allowed" );
    is( scalar @{ $move_up_result_longer_path->{doors_in_path} }, 1, "1 Door in path returned" );
    is( $move_up_result_longer_path->{doors_in_path}[0]->position->position, 'top', "Door in path returned, correct position" );
    is( $move_up_result_longer_path->{doors_in_path}[0]->dungeon_grid_id, $sector_grid->[3][2]->id, "Door in path returned, correct sector" );

}

sub check_has_path_longer_route_could_add_door_in_path_erroneously : Tests(2) {
    my $self = shift;

    # GIVEN
    my $sector_grid;
    for my $x ( 1 .. 2 ) {
        for my $y ( 1 .. 3 ) {
            my @walls;
            my @doors;

            if ( $x == 2 && $y == 1 ) {
                @walls = ( 'top', 'left', 'right' );
            }
            if ( $x == 2 && $y == 2 ) {
                @walls = ( 'left', 'right' );
            }
            if ( $x == 2 && $y == 3 ) {
                @walls = ( 'bottom', 'right', 'left' );
                @doors = ('left');
            }
            if ( $x == 1 && $y == 3 ) {
                @walls = ( 'top', 'bottom', 'left', 'right' );
                @doors = ('right');
            }

            my $sector = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid(
                $self->{schema},
                x     => $x,
                y     => $y,
                walls => \@walls,
                doors => \@doors,
            );
            $sector_grid->[$x][$y] = $sector;
        }
    }

    # WHEN
    my $result = $self->{dungeon}->check_has_path( $sector_grid->[2][1], $sector_grid->[2][3], $sector_grid, 3 );

    # THEN
    is( $result->{has_path},                  1, "Have path to sector" );
    is( scalar @{ $result->{doors_in_path} }, 0, "No Doors in path returned" );
}

sub test_populate_sector_paths_1 : Tests(1) {
    my $self = shift;

    # GIVEN
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );
    my $dungeon_room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, dungeon_id => $dungeon->id );

    my @expected_allowed_to_move_to = ( { x => 1, y => 1 }, { x => 1, y => 2 }, { x => 1, y => 3 }, { x => 2, y => 1 }, { x => 2, y => 3 }, { x => 3, y => 1 },
        { x => 3, y => 2 }, { x => 3, y => 3 } );

    my $start_sector;

    my %expected_sectors_by_id;

    for my $x ( 1 .. 4 ) {
        for my $y ( 1 .. 4 ) {
            my @walls;
            my @doors;

            if ( $x == 3 && $y == 1 ) {
                @walls = ( 'top', 'right' );
            }
            if ( $x == 1 && $y == 1 ) {
                @walls = ( 'bottom', 'right' );
                @doors = ('right');
            }

            my $sector = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid(
                $self->{schema},
                x               => $x,
                y               => $y,
                walls           => \@walls,
                doors           => \@doors,
                dungeon_room_id => $dungeon_room->id,
            );

            if ( grep { $_->{x} == $x && $_->{y} == $y } @expected_allowed_to_move_to ) {
                $expected_sectors_by_id{ $sector->id } = 1;
            }

            if ( $x == 2 && $y == 2 ) {
                $start_sector = $sector;
            }
        }
    }

    # WHEN
    $dungeon->populate_sector_paths();
    my $allowed_to_move_sectors = $start_sector->sectors_allowed_to_move_to(1);

    # THEN
    is_deeply( $allowed_to_move_sectors, \%expected_sectors_by_id, "Correct sectors are allowed to move to" );
}

sub test_populate_sector_paths_2 : Tests(1) {
    my $self = shift;

    # GIVEN
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );
    my $dungeon_room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, dungeon_id => $dungeon->id );

    my @sectors;
    my %expected_allowed_to_move_to;
    for my $x ( 1 .. 5 ) {
        for my $y ( 1 .. 5 ) {
            my @walls;
            my @doors;

            if ( $x == 1 && $y == 2 ) {
                @walls = ( 'bottom', 'right' );
            }
            if ( $x == 2 && $y == 2 ) {
                @walls = ('left');
            }
            if ( $x == 1 && $y == 3 ) {
                @walls = ('top');
            }
            if ( $x == 1 && $y == 4 ) {
                @walls = ('top');
            }
            if ( $x == 2 && $y == 4 ) {
                @walls = ( 'top', 'right' );
                @doors = ('top');
            }
            if ( $x == 2 && $y == 5 ) {
                @walls = ('right');
            }
            if ( $x == 4 && $y == 3 ) {
                @walls = ('left');
            }

            my $sector = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid(
                $self->{schema},
                x               => $x,
                y               => $y,
                walls           => \@walls,
                doors           => \@doors,
                dungeon_room_id => $dungeon_room->id,
            );

            push @sectors, $sector;
            unless ( ( $x == 3 && $y == 3 ) || ( $x == 1 && $y == 2 ) ) {
                $expected_allowed_to_move_to{ $sector->id } = 1;
            }
        }
    }

    my $start_sector = $sectors[12];    # 3,3

    # WHEN
    $dungeon->populate_sector_paths();
    my $allowed_to_move_sectors = $start_sector->sectors_allowed_to_move_to(2);

    # THEN
    is_deeply( $allowed_to_move_sectors, \%expected_allowed_to_move_to, "Correct sectors are allowed to move to" )
      or diag "got: " . Dumper($allowed_to_move_sectors) . "\nexpected: " . Dumper( \%expected_allowed_to_move_to );
}

sub test_populate_sector_paths_3 : Tests(1) {
    my $self = shift;

    # GIVEN
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );
    my $dungeon_room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, dungeon_id => $dungeon->id );

    my $sectors_by_coord;
    for my $x ( 1 .. 5 ) {
        for my $y ( 1 .. 5 ) {
            my @walls;
            my @doors;

            if ( $x == 5 && $y == 5 ) {
                @walls = ( 'left', 'top' );
                @doors = ('top');
            }
            if ( $x == 5 && $y == 4 ) {
                @walls = ('bottom');
                @doors = ('bottom');
            }
            if ( $x == 4 && $y == 4 ) {
                @walls = ( 'bottom', 'left' );
            }
            if ( $x == 4 && $y == 5 ) {
                @walls = ( 'right', 'top' );
            }
            if ( $x == 4 && $y == 3 ) {
                @walls = ('left');
                @doors = ('left');
            }
            if ( $x == 4 && $y == 2 ) {
                @walls = ('left');
            }
            if ( $x == 4 && $y == 1 ) {
                @walls = ('left');
            }

            my $sector = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid(
                $self->{schema},
                x               => $x,
                y               => $y,
                walls           => \@walls,
                doors           => \@doors,
                dungeon_room_id => $dungeon_room->id,
            );

            $sectors_by_coord->[$x][$y] = $sector;
        }
    }

    my $start_sector = $sectors_by_coord->[5][5];

    my %expected_allowed_to_move_to;

    $expected_allowed_to_move_to{ $sectors_by_coord->[5][2]->id } = 1;
    $expected_allowed_to_move_to{ $sectors_by_coord->[5][3]->id } = 1;
    $expected_allowed_to_move_to{ $sectors_by_coord->[5][4]->id } = 1;
    $expected_allowed_to_move_to{ $sectors_by_coord->[4][2]->id } = 1;
    $expected_allowed_to_move_to{ $sectors_by_coord->[4][3]->id } = 1;
    $expected_allowed_to_move_to{ $sectors_by_coord->[4][4]->id } = 1;
    $expected_allowed_to_move_to{ $sectors_by_coord->[4][5]->id } = 1;
    $expected_allowed_to_move_to{ $sectors_by_coord->[3][2]->id } = 1;
    $expected_allowed_to_move_to{ $sectors_by_coord->[3][3]->id } = 1;
    $expected_allowed_to_move_to{ $sectors_by_coord->[3][4]->id } = 1;
    $expected_allowed_to_move_to{ $sectors_by_coord->[3][5]->id } = 1;
    $expected_allowed_to_move_to{ $sectors_by_coord->[2][2]->id } = 1;
    $expected_allowed_to_move_to{ $sectors_by_coord->[2][3]->id } = 1;
    $expected_allowed_to_move_to{ $sectors_by_coord->[2][4]->id } = 1;
    $expected_allowed_to_move_to{ $sectors_by_coord->[2][5]->id } = 1;

    # WHEN
    $dungeon->populate_sector_paths();
    my $allowed_to_move_sectors = $start_sector->sectors_allowed_to_move_to(3);

    # THEN
    is_deeply( $allowed_to_move_sectors, \%expected_allowed_to_move_to, "Correct sectors are allowed to move to" );
}

sub test_populate_sector_paths_4 : Tests(1) {
    my $self = shift;

    # GIVEN
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );
    my $dungeon_room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, dungeon_id => $dungeon->id );

    my $sectors_by_coord;
    for my $x ( 1 .. 3 ) {
        for my $y ( 1 .. 3 ) {
            my @walls;
            my @doors;

            if ( $x == 1 && $y == 1 ) {
                @walls = ('bottom');
            }
            if ( $x == 2 && $y == 1 ) {
                @walls = ( 'bottom', 'right' );
                @doors = ('right');
            }

            if ( $x == 3 && $y == 1 ) {
                @walls = ('left');
                @doors = ('left');
            }

            if ( $x == 1 && $y == 2 ) {
                @walls = ( 'top', 'bottom' );
            }

            if ( $x == 2 && $y == 2 ) {
                @walls = ( 'top', 'bottom' );
                @doors = ('bottom');
            }

            if ( $x == 3 && $y == 2 ) {
                @walls = ('bottom');
            }

            if ( $x == 1 && $y == 3 ) {
                @walls = ( 'top', 'right' );
            }
            if ( $x == 2 && $y == 3 ) {
                @walls = ( 'top', 'left' );
                @doors = ('top');
            }
            if ( $x == 3 && $y == 3 ) {
                @walls = ('top');
            }

            my $sector = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid(
                $self->{schema},
                x               => $x,
                y               => $y,
                walls           => \@walls,
                doors           => \@doors,
                dungeon_room_id => $dungeon_room->id,
            );

            $sectors_by_coord->[$x][$y] = $sector;
        }
    }

    my $start_sector = $sectors_by_coord->[2][2];

    my %expected_allowed_to_move_to;
    $expected_allowed_to_move_to{ $sectors_by_coord->[1][2]->id } = 1;
    $expected_allowed_to_move_to{ $sectors_by_coord->[3][1]->id } = 1;
    $expected_allowed_to_move_to{ $sectors_by_coord->[3][2]->id } = 1;
    $expected_allowed_to_move_to{ $sectors_by_coord->[2][3]->id } = 1;
    $expected_allowed_to_move_to{ $sectors_by_coord->[3][3]->id } = 1;

    # WHEN
    $dungeon->populate_sector_paths(1);
    my $allowed_to_move_sectors = $start_sector->sectors_allowed_to_move_to(1);

    # THEN
    is_deeply( $allowed_to_move_sectors, \%expected_allowed_to_move_to, "Correct sectors are allowed to move to" );
}

sub test_populate_sector_paths_multiple_doors_in_path : Tests(2) {
    my $self = shift;

    # GIVEN
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );
    my $dungeon_room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, dungeon_id => $dungeon->id );

    my $sector1 = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid(
        $self->{schema},
        x               => 1,
        y               => 1,
        walls           => ['right'],
        doors           => ['right'],
        dungeon_room_id => $dungeon_room->id,
    );

    my $sector2 = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid(
        $self->{schema},
        x               => 2,
        y               => 1,
        walls           => [ 'right', 'left' ],
        doors           => [ 'right', 'left' ],
        dungeon_room_id => $dungeon_room->id,
    );

    my $sector3 = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid(
        $self->{schema},
        x               => 3,
        y               => 1,
        walls           => ['left'],
        doors           => ['left'],
        dungeon_room_id => $dungeon_room->id,
    );

    # WHEN
    $dungeon->populate_sector_paths();

    # THEN
    my $path1 = $self->{schema}->resultset('Dungeon_Sector_Path')->find(
        {
            sector_id   => $sector1->id,
            has_path_to => $sector3->id,
        },
        {
            prefetch => 'doors_in_path',
        }
    );

    is( $path1->distance,             2, "Distance populated correctly" );
    is( $path1->doors_in_path->count, 2, "Two doors in path recorded" );
}

sub test_populate_sector_paths_multiple_doors_in_path_diagonal : Tests(2) {
    my $self = shift;

    # GIVEN
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );
    my $dungeon_room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, dungeon_id => $dungeon->id );

    my $sector1 = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid(
        $self->{schema},
        x               => 1,
        y               => 1,
        walls           => ['right'],
        doors           => ['right'],
        dungeon_room_id => $dungeon_room->id,
    );

    my $sector2 = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid(
        $self->{schema},
        x               => 2,
        y               => 1,
        walls           => ['left'],
        doors           => ['left'],
        dungeon_room_id => $dungeon_room->id,
    );

    my $sector3 = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid(
        $self->{schema},
        x               => 1,
        y               => 2,
        walls           => ['right'],
        dungeon_room_id => $dungeon_room->id,
    );

    my $sector4 = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid(
        $self->{schema},
        x               => 2,
        y               => 2,
        walls           => ['left'],
        dungeon_room_id => $dungeon_room->id,
    );

    # WHEN
    $dungeon->populate_sector_paths();

    # THEN
    my $path1 = $self->{schema}->resultset('Dungeon_Sector_Path')->find(
        {
            sector_id   => $sector3->id,
            has_path_to => $sector4->id,
        },
        {
            prefetch => 'doors_in_path',
        }
    );

    {
        local $TODO = "Currently doesn't work correctly, due to path distances not always being optimal";
        is( $path1->distance, 1, "Distance populated correctly" );
    }
    is( $path1->doors_in_path->count, 1, "door in path recorded" );
}

sub test_populate_sector_paths_multiple_floors : Tests(1) {
    my $self = shift;

    # GIVEN
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );
    my $dungeon_room1 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema},
        dungeon_id   => $dungeon->id,
        floor        => 1,
        create_walls => 1,
        top_left     => { x => 1, y => 1 },
        bottom_right => { x => 3, y => 3 },
        sector_walls => {
            '1,1' => 'right',
            '1,2' => 'right',
            '1,3' => 'right',
            '2,1' => 'left',
            '2,2' => 'left',
            '2,3' => 'left',
          }
    );

    my $dungeon_room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema},
        dungeon_id   => $dungeon->id,
        floor        => 2,
        create_walls => 1,
        top_left     => { x => 1, y => 1 },
        bottom_right => { x => 3, y => 3 },
        sector_walls => {
            '2,1' => 'right',
            '2,2' => 'right',
            '2,3' => 'right',
            '3,1' => 'left',
            '3,2' => 'left',
            '3,3' => 'left',
          }
    );

    my @expected_allowed_to_move_to = ( { x => 2, y => 1 }, { x => 2, y => 3 }, { x => 3, y => 1 }, { x => 3, y => 2 }, { x => 3, y => 3 } );

    my $start_sector;

    my %expected_sectors_by_id;
    my %sectors_by_id;

    # Create first room
    foreach my $sector ( $dungeon_room1->sectors ) {

        #warn $sector->x . "," . $sector->y;
        $sectors_by_id{ $sector->id } = { x => $sector->x, y => $sector->y };
        if ( grep { $_->{x} == $sector->x && $_->{y} == $sector->y } @expected_allowed_to_move_to ) {
            $expected_sectors_by_id{ $sector->id } = 1;
        }

        if ( $sector->x == 2 && $sector->y == 2 ) {
            $start_sector = $sector;
        }
    }

    # WHEN
    $dungeon->populate_sector_paths();
    my $allowed_to_move_sectors = $start_sector->sectors_allowed_to_move_to(1);

    # THEN
    is_deeply( $allowed_to_move_sectors, \%expected_sectors_by_id, "Correct sectors are allowed to move to" )
      or diag Dumper \%sectors_by_id;
}

sub test_populate_sector_paths_multiple_floors_with_doors : Tests(1) {
    my $self = shift;

    # GIVEN
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );
    my $dungeon_room1 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema},
        dungeon_id   => $dungeon->id,
        floor        => 2,
        create_walls => 1,
        top_left     => { x => 1, y => 1 },
        bottom_right => { x => 3, y => 3 },
        sector_doors => {
            '2,3' => 'bottom',
        },
    );
    my $dungeon_room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema},
        dungeon_id   => $dungeon->id,
        floor        => 2,
        create_walls => 1,
        top_left     => { x => 1, y => 4 },
        bottom_right => { x => 3, y => 6 },
        sector_doors => {
            '2,4' => 'top',
        },
    );

    my $dungeon_room3 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema},
        dungeon_id   => $dungeon->id,
        floor        => 1,
        create_walls => 1,
        top_left     => { x => 1, y => 1 },
        bottom_right => { x => 3, y => 6 },
    );

    my @expected_allowed_to_move_to = ( { x => 1, y => 2 }, { x => 2, y => 2 }, { x => 3, y => 2 }, { x => 1, y => 3 }, { x => 3, y => 3 },
        { x => 1, y => 4 }, { x => 2, y => 4 }, { x => 3, y => 4 }
    );

    my $start_sector;

    my %expected_sectors_by_id;
    my %sectors_by_id;

    # Create first room
    foreach my $sector ( $dungeon_room1->sectors, $dungeon_room2->sectors ) {

        #warn $sector->x . "," . $sector->y;
        $sectors_by_id{ $sector->id } = { x => $sector->x, y => $sector->y };
        if ( grep { $_->{x} == $sector->x && $_->{y} == $sector->y } @expected_allowed_to_move_to ) {
            $expected_sectors_by_id{ $sector->id } = 1;
        }

        if ( $sector->x == 2 && $sector->y == 3 ) {
            $start_sector = $sector;
        }
    }

    # WHEN
    $dungeon->populate_sector_paths();
    my $allowed_to_move_sectors = $start_sector->sectors_allowed_to_move_to(1);

    # THEN
    my $result = is_deeply( $allowed_to_move_sectors, \%expected_sectors_by_id, "Correct sectors are allowed to move to" );

    unless ($result) {
        diag "All sectors: " . Dumper \%sectors_by_id;
        diag "Expected sectors: " . Dumper \%expected_sectors_by_id;
        diag "Actual sectors: " . Dumper $allowed_to_move_sectors;
    }
}

1;
