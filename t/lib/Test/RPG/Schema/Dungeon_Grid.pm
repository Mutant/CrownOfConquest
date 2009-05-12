package Test::RPG::Schema::Dungeon_Grid;

use strict;
use warnings;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Dungeon_Grid;

sub startup : Test(startup => 1) {
    my $self = shift;

    $self->{mock_rpg_schema} = Test::MockObject->new();
    $self->{mock_rpg_schema}->fake_module( 'RPG::Schema', 'config' => sub { $self->{config} }, );

    use_ok 'RPG::Schema::Dungeon_Grid';
}

sub dungeon_setup : Tests(setup) {
    my $self = shift;

    # Create Dungeon_Positions
    my %positions;
    foreach my $position (qw/top bottom left right/) {
        my $position_rec = $self->{schema}->resultset('Dungeon_Position')->create( { position => $position, } );
        $positions{$position} = $position_rec->id;
    }

    $self->{positions} = \%positions;

    undef $RPG::Schema::Dungeon_Grid::can_move_to;
}

sub test_can_move_to : Test(13) {
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
            expected_result => 1,
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
            expected_result => 1,
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
            expected_result => 1,
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
            expected_result => 1,
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
            expected_result => 1,
        },

    );

    # WHEN
    my %results;
    while ( my ( $test_name, $test_data ) = each %tests ) {
        undef $RPG::Schema::Dungeon_Grid::can_move_to;
        my $first_sector  = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid( $self->{schema}, %{ $test_data->{first_sector} } );
        my $second_sector = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid( $self->{schema}, %{ $test_data->{second_sector} } );

        $results{$test_name} = $first_sector->can_move_to($second_sector);
    }

    # THEN
    while ( my ( $test_name, $test_data ) = each %tests ) {
        is( $results{$test_name}, $test_data->{expected_result}, "Got expected result for $test_name" );
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
    my $result = $sector_grid->[1][1]->_check_has_path( $sector_grid->[3][3], $sector_grid, 2 );

    is( $result, 1, "Path found, as nothing blocking sectors" );
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
    my $result = $sector_grid->[1][1]->_check_has_path( $sector_grid->[3][3], $sector_grid, 2 );

    # THEN
    is( $result, 0, "Path not found, as wall blocks destination" );
}

sub check_has_path_walls_force_longer_path : Tests(3) {
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
    my $move_up_result             = $sector_grid->[2][2]->_check_has_path( $sector_grid->[2][1], $sector_grid, 1 );
    my $move_top_right_result      = $sector_grid->[2][2]->_check_has_path( $sector_grid->[3][1], $sector_grid, 1 );
    my $move_up_result_longer_path = $sector_grid->[2][2]->_check_has_path( $sector_grid->[2][1], $sector_grid, 2 );

    # THEN
    is( $move_up_result,             0, "Couldn't move up, as path too long (via door)" );
    is( $move_top_right_result,      1, "Could move to top right via door" );
    is( $move_up_result_longer_path, 1, "Could move up when longer move allowed" );
}

sub test_allowed_to_move_to_sectors_1 : Tests(16) {
    my $self = shift;

    # GIVEN
    my @sectors;
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
                x     => $x,
                y     => $y,
                walls => \@walls,
                doors => \@doors,
            );

            push @sectors, $sector;
        }
    }

    my $start_sector = $sectors[5];    # 2,2

    my $expected_allowed_to_move_to;
    $expected_allowed_to_move_to->[1][1] = 1;
    $expected_allowed_to_move_to->[1][2] = 1;
    $expected_allowed_to_move_to->[1][3] = 1;
    $expected_allowed_to_move_to->[2][1] = 1;
    $expected_allowed_to_move_to->[2][3] = 1;
    $expected_allowed_to_move_to->[3][1] = 1;
    $expected_allowed_to_move_to->[3][2] = 1;
    $expected_allowed_to_move_to->[3][3] = 1;

    # WHEN
    my $allowed_to_move_to = $start_sector->allowed_to_move_to_sectors( \@sectors, 1 );

    # THEN
    for my $x ( 1 .. 4 ) {
        for my $y ( 1 .. 4 ) {
            is( $allowed_to_move_to->[$x][$y], $expected_allowed_to_move_to->[$x][$y] || 0, "Allowed to move for $x, $y as expected" );
        }
    }
}

sub test_allowed_to_move_to_sectors_2 : Tests(25) {
    my $self = shift;

    # GIVEN
    my @sectors;
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
                x     => $x,
                y     => $y,
                walls => \@walls,
                doors => \@doors,
            );

            push @sectors, $sector;
        }
    }

    my $start_sector = $sectors[12];    # 3,3

    my $expected_allowed_to_move_to;
    for my $x ( 1 .. 5 ) {
        for my $y ( 1 .. 5 ) {
            $expected_allowed_to_move_to->[$x][$y] = 1;
        }
    }
    $expected_allowed_to_move_to->[3][3] = 0;
    $expected_allowed_to_move_to->[1][2] = 0;

    # WHEN
    my $allowed_to_move_to = $start_sector->allowed_to_move_to_sectors( \@sectors, 2 );

    # THEN
    for my $x ( 1 .. 5 ) {
        for my $y ( 1 .. 5 ) {
            is( $allowed_to_move_to->[$x][$y], $expected_allowed_to_move_to->[$x][$y] || 0, "Allowed to move for $x, $y as expected" );
        }
    }
}

sub test_allowed_to_move_to_sectors_3 : Tests(25) {
    my $self = shift;

    # GIVEN
    my @sectors;
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
                x     => $x,
                y     => $y,
                walls => \@walls,
                doors => \@doors,
            );

            push @sectors, $sector;
        }
    }

    my $start_sector = $sectors[24];    # 5,5

    my $expected_allowed_to_move_to;
    for my $x ( 1 .. 5 ) {
        for my $y ( 1 .. 5 ) {
            $expected_allowed_to_move_to->[$x][$y] = 0;
        }
    }

    $expected_allowed_to_move_to->[5][2] = 1;
    $expected_allowed_to_move_to->[5][3] = 1;
    $expected_allowed_to_move_to->[5][4] = 1;
    $expected_allowed_to_move_to->[4][2] = 1;
    $expected_allowed_to_move_to->[4][3] = 1;
    $expected_allowed_to_move_to->[4][4] = 1;
    $expected_allowed_to_move_to->[3][2] = 1;
    $expected_allowed_to_move_to->[3][3] = 1;
    $expected_allowed_to_move_to->[3][4] = 1;
    $expected_allowed_to_move_to->[2][2] = 1;
    $expected_allowed_to_move_to->[2][3] = 1;
    $expected_allowed_to_move_to->[2][4] = 1;

    # WHEN
    my $allowed_to_move_to = $start_sector->allowed_to_move_to_sectors( \@sectors, 3 );

    # THEN
    for my $x ( 1 .. 5 ) {
        for my $y ( 1 .. 5 ) {
            is( $allowed_to_move_to->[$x][$y], $expected_allowed_to_move_to->[$x][$y] || 0, "Allowed to move for $x, $y as expected" );
        }
    }
}

sub test_has_wall : Tests(4) {
    my $self = shift;

    # GIVEN
    my $sector = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid( $self->{schema}, walls => [ 'left', 'top' ], x=>1, y=>1 );
    
    # WHEN
    my %results;
    for my $wall (qw/left right top bottom/) {
        $results{$wall} = $sector->has_wall($wall);
    }
    
    # THEN
    is($results{left}, 1, "Has a left wall");
    is($results{right}, 0, "Doesn't have a right wall");
    is($results{top}, 1, "Has a top wall");
    is($results{bottom}, 0, "Doesn't have a bottom wall");
}

1;
