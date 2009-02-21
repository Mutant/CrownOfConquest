use strict;
use warnings;

package Test::RPG::NewDay::Dungeon;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Data::Dumper;

use Test::MockObject;
use Test::More;
use Test::Exception;

sub dungeon_startup : Test(startup => 1) {
    my $self = shift;

    $self->{dice} = Test::MockObject->new();

    $self->{dice}->fake_module(
        'Games::Dice::Advanced',
        roll => sub {
            if ( $self->{rolls} ) {
                my $ret = $self->{rolls}[ $self->{counter} ];
                $self->{counter}++;
                return $ret;
            }
            else {
                return $self->{roll_result} || 0;
            }
        }
    );

    use_ok 'RPG::NewDay::Action::Dungeon';

    my $logger = Test::MockObject->new();
    #$logger->set_always('debug');
    $logger->mock('debug', sub { warn @_->[1] . "\n" } );

    $self->{context} = Test::MockObject->new();

    $self->{context}->set_always( 'logger', $logger );
    $self->{context}->set_always( 'schema', $self->{schema} );
    $self->{context}->set_always( 'config', $self->{config} );
    $self->{context}->set_isa('RPG::NewDay::Context');
}

sub dungeon_shutdown : Test(shutdown) {
    my $self = shift;

    delete $INC{'Games/Dice/Advanced.pm'};
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

    $self->{config} = {
        max_x_dungeon_room_size => 6,
        max_y_dungeon_room_size => 6,
    };

    $self->{dungeon} = RPG::NewDay::Action::Dungeon->new( context => $self->{context} );
}

sub test_find_room_dimensions : Tests(no_plan) {
    my $self = shift;

    # GIVEN
    my @tests = (
        {
            start_x  => 1,
            start_y  => 1,
            rolls    => [ 3, 3, 1, 1 ],
            expected => [ 1, 1, 3, 3 ],

        },
        {
            start_x  => 5,
            start_y  => 5,
            rolls    => [ 2, 2, 2, 2 ],
            expected => [ 5, 5, 2, 2 ],
        },
        {
            start_x  => 5,
            start_y  => 5,
            rolls    => [ 5, 5, 1, 3 ],
            expected => [ 1, 3, 5, 5 ],
        },
        {
            start_x  => 6,
            start_y  => 6,
            rolls    => [ 6, 5, 6, 2 ],
            expected => [ 6, 3, 6, 5 ],
        },

    );

    foreach my $test (@tests) {
        $self->{counter} = 0;
        $self->{rolls}   = $test->{rolls};

        my @result = $self->{dungeon}->_find_room_dimensions( $test->{start_x}, $test->{start_y} );

        is( $result[0], $test->{expected}[0], "Top x set correctly" );
        is( $result[1], $test->{expected}[1], "Top y set correctly" );
        is( $result[2], $test->{expected}[2], "X size set correctly" );
        is( $result[3], $test->{expected}[3], "Y size set correctly" );
    }

    undef $self->{rolls};

}

sub test_create_room_simple : Test(28) {
    my $self = shift;

    # GIVEN
    my $mock_dungeon = Test::MockObject->new();
    $mock_dungeon->set_always( 'id', 1 );

    $self->{roll_result} = 3;

    my $expected_sectors;
    $expected_sectors->[1][1] = [ 'top', 'left' ];
    $expected_sectors->[1][2] = ['left'];
    $expected_sectors->[1][3] = [ 'left', 'bottom' ];
    $expected_sectors->[2][1] = ['top'];
    $expected_sectors->[2][2] = [];
    $expected_sectors->[2][3] = ['bottom'];
    $expected_sectors->[3][1] = [ 'right', 'top' ];
    $expected_sectors->[3][2] = ['right'];
    $expected_sectors->[3][3] = [ 'bottom', 'right' ];

    # WHEN
    my @sectors = $self->{dungeon}->_create_room( $mock_dungeon, 1, 1, [], $self->{positions} );

    # THEN
    is( scalar @sectors, 9, "9 new sectors created" );

    my $sectors_seen;
    foreach my $sector (@sectors) {
        is( $sector->dungeon_room->dungeon_id, 1, "Sector created in correct dungeon" );

        is( defined $expected_sectors->[ $sector->x ][ $sector->y ], 1, "Sector " . $sector->x . ", " . $sector->y . " was expected" );

        my @walls = sort $sector->sides_with_walls;

        my @expected_walls = sort @{ $expected_sectors->[ $sector->x ][ $sector->y ] };

        is_deeply( \@walls, \@expected_walls, "Walls created as expected" );
    }
}

sub test_create_room_with_offset : Test(28) {
    my $self = shift;

    # GIVEN
    my $mock_dungeon = Test::MockObject->new();
    $mock_dungeon->set_always( 'id', 1 );

    $self->{counter} = 0;
    $self->{rolls} = [ 3, 3, 3, 1 ];

    my $expected_sectors;
    $expected_sectors->[5][3] = [ 'top', 'left' ];
    $expected_sectors->[5][4] = ['left'];
    $expected_sectors->[5][5] = [ 'left', 'bottom' ];
    $expected_sectors->[6][3] = ['top'];
    $expected_sectors->[6][4] = [];
    $expected_sectors->[6][5] = ['bottom'];
    $expected_sectors->[7][3] = [ 'right', 'top' ];
    $expected_sectors->[7][4] = ['right'];
    $expected_sectors->[7][5] = [ 'bottom', 'right' ];

    # WHEN
    my @sectors = $self->{dungeon}->_create_room( $mock_dungeon, 5, 5, [], $self->{positions} );

    # THEN
    is( scalar @sectors, 9, "9 new sectors created" );

    my $sectors_seen;
    foreach my $sector (@sectors) {
        is( $sector->dungeon_room->dungeon_id, 1, "Sector created in correct dungeon" );

        is( defined $expected_sectors->[ $sector->x ][ $sector->y ], 1, "Sector " . $sector->x . ", " . $sector->y . " was expected" );

        my @walls = sort $sector->sides_with_walls;

        my @expected_walls = sort @{ $expected_sectors->[ $sector->x ][ $sector->y ] };

        is_deeply( \@walls, \@expected_walls, "Walls created as expected" );
    }
}

sub test_create_room_with_rooms_blocking : Test(17) {
    my $self = shift;

    # GIVEN
    my $mock_dungeon = Test::MockObject->new();
    $mock_dungeon->set_always( 'id', 1 );

    $self->{counter} = 0;
    $self->{rolls} = [ 3, 2, 1, 1 ];

    my @sectors = $self->{dungeon}->_create_room( $mock_dungeon, 1, 1, [], $self->{positions} );

    is( scalar @sectors, 6, "Sanity check existing room" );

    my $existing_sectors;
    foreach my $sector (@sectors) {
        $existing_sectors->[ $sector->x ][ $sector->y ] = $sector;
    }

    $self->{counter} = 0;
    $self->{rolls} = [ 3, 3, 2, 1 ];

    my $expected_sectors;
    $expected_sectors->[4][1] = [ 'top',    'right', 'left' ];
    $expected_sectors->[4][2] = [ 'right',  'left' ];
    $expected_sectors->[2][3] = [ 'bottom', 'left', 'top' ];
    $expected_sectors->[3][3] = [ 'bottom', 'top' ];
    $expected_sectors->[4][3] = [ 'bottom', 'right' ];

    # WHEN
    @sectors = $self->{dungeon}->_create_room( $mock_dungeon, 3, 3, $existing_sectors, $self->{positions} );

    # THEN
    is( scalar @sectors, 5, "5 new sectors created" );

    my $sectors_seen;
    foreach my $sector (@sectors) {
        is( $sector->dungeon_room->dungeon_id, 1, "Sector created in correct dungeon" );

        is( defined $expected_sectors->[ $sector->x ][ $sector->y ], 1, "Sector " . $sector->x . ", " . $sector->y . " was expected" );

        my @walls = sort $sector->sides_with_walls;

        my @expected_walls = sort @{ $expected_sectors->[ $sector->x ][ $sector->y ] };

        is_deeply( \@walls, \@expected_walls, "Walls created as expected" );
    }
}

sub test_create_room_with_non_contiguous_sectors : Test(11) {
    my $self = shift;

    # GIVEN
    my $mock_dungeon = Test::MockObject->new();
    $mock_dungeon->set_always( 'id', 1 );

    $self->{counter} = 0;
    $self->{rolls} = [ 3, 1, 1, 1 ];

    my @sectors = $self->{dungeon}->_create_room( $mock_dungeon, 1, 2, [], $self->{positions} );

    is( scalar @sectors, 3, "Sanity check existing room" );

    my $existing_sectors;
    foreach my $sector (@sectors) {
        $existing_sectors->[ $sector->x ][ $sector->y ] = $sector;
    }

    $self->{counter} = 0;
    $self->{rolls} = [ 3, 3, 1, 1 ];

    my $expected_sectors;
    $expected_sectors->[1][1] = [ 'top',    'bottom', 'left' ];
    $expected_sectors->[2][1] = [ 'top',    'bottom' ];
    $expected_sectors->[3][1] = [ 'bottom', 'right', 'top' ];

    # WHEN
    @sectors = $self->{dungeon}->_create_room( $mock_dungeon, 1, 1, $existing_sectors, $self->{positions} );

    # THEN
    is( scalar @sectors, 3, "3 new sectors created" );

    my $sectors_seen;
    foreach my $sector (@sectors) {
        is( $sector->dungeon_room->dungeon_id, 1, "Sector created in correct dungeon" );

        is( defined $expected_sectors->[ $sector->x ][ $sector->y ], 1, "Sector " . $sector->x . ", " . $sector->y . " was expected" );

        my @walls = sort $sector->sides_with_walls;

        my @expected_walls = sort @{ $expected_sectors->[ $sector->x ][ $sector->y ] };

        is_deeply( \@walls, \@expected_walls, "Walls created as expected" );
    }
}

sub test_find_wall_to_join_simple : Test(1) {
    my $self = shift;

    # GIVEN
    my $sector = $self->{schema}->resultset('Dungeon_Grid')->create(
        {
            x => 1,
            y => 2,
        }
    );

    my $wall = $self->{schema}->resultset('Dungeon_Wall')->create(
        {
            dungeon_grid_id => $sector->id,
            position_id     => $self->{positions}{'bottom'},
        }
    );

    my $existing_sectors;
    $existing_sectors->[1][2] = $sector;

    # WHEN
    my ($wall_found) = $self->{dungeon}->_find_wall_to_join( $existing_sectors, );

    # THEN
    is( $wall->id, $wall_found->id, "Wall to join found" );

}

sub test_find_wall_to_join_one_sector_at_left_of_map : Test(1) {
    my $self = shift;

    # GIVEN
    my $sector1 = $self->{schema}->resultset('Dungeon_Grid')->create(
        {
            x => 1,
            y => 1,
        }
    );

    my $wall1 = $self->{schema}->resultset('Dungeon_Wall')->create(
        {
            dungeon_grid_id => $sector1->id,
            position_id     => $self->{positions}{'left'},
        }
    );

    my $sector2 = $self->{schema}->resultset('Dungeon_Grid')->create(
        {
            x => 2,
            y => 1,
        }
    );

    my $wall2 = $self->{schema}->resultset('Dungeon_Wall')->create(
        {
            dungeon_grid_id => $sector2->id,
            position_id     => $self->{positions}{'right'},
        }
    );

    my $existing_sectors;
    $existing_sectors->[1][1] = $sector1;
    $existing_sectors->[2][1] = $sector2;

    # WHEN
    my ($wall_found) = $self->{dungeon}->_find_wall_to_join( $existing_sectors, );

    # THEN
    is( $wall2->id, $wall_found->id, "Wall to join is wall not at far left of map" );
}

sub test_find_wall_to_join_one_sector_with_no_available_walls : Test(1) {
    my $self = shift;

    # GIVEN
    my $sector1 = $self->{schema}->resultset('Dungeon_Grid')->create(
        {
            x => 2,
            y => 2,
        }
    );

    my $wall1 = $self->{schema}->resultset('Dungeon_Wall')->create(
        {
            dungeon_grid_id => $sector1->id,
            position_id     => $self->{positions}{'bottom'},
        }
    );

    my $sector2 = $self->{schema}->resultset('Dungeon_Grid')->create(
        {
            x => 2,
            y => 3,
        }
    );

    my $wall2 = $self->{schema}->resultset('Dungeon_Wall')->create(
        {
            dungeon_grid_id => $sector2->id,
            position_id     => $self->{positions}{'bottom'},
        }
    );

    my $existing_sectors;
    $existing_sectors->[2][2] = $sector1;
    $existing_sectors->[2][3] = $sector2;

    # WHEN
    my ($wall_found) = $self->{dungeon}->_find_wall_to_join( $existing_sectors, );

    # THEN
    is( $wall2->id, $wall_found->id, "Wall to join is wall not one with adjacent sector" );
}

sub test_find_wall_to_join_one_sector_with_door_blocking_one_wall : Test(1) {
    my $self = shift;

    # GIVEN
    my $sector1 = $self->{schema}->resultset('Dungeon_Grid')->create(
        {
            x => 2,
            y => 2,
        }
    );

    my $wall1 = $self->{schema}->resultset('Dungeon_Wall')->create(
        {
            dungeon_grid_id => $sector1->id,
            position_id     => $self->{positions}{'bottom'},
        }
    );

    my $wall2 = $self->{schema}->resultset('Dungeon_Wall')->create(
        {
            dungeon_grid_id => $sector1->id,
            position_id     => $self->{positions}{'left'},
        }
    );

    my $door = $self->{schema}->resultset('Door')->create(
        {
            dungeon_grid_id => $sector1->id,
            position_id     => $self->{positions}{'bottom'},
        }
    );

    my $existing_sectors;
    $existing_sectors->[2][2] = $sector1;

    # WHEN
    my ($wall_found) = $self->{dungeon}->_find_wall_to_join( $existing_sectors, );

    # THEN
    is( $wall2->id, $wall_found->id, "Wall to join is wall not at far left of map" );
}

sub test_has_available_path_simple : Tests(1) {
    my $self = shift;

    # GIVEN
    my ( $start_x, $start_y ) = ( 1, 1 );
    my ( $dest_x,  $dest_y )  = ( 1, 2 );
    my @room_range = ( 1, 1, 1, 2 );

    # WHEN
    my $has_path = $self->{dungeon}->_has_available_path( $dest_x, $dest_y, $start_x, $start_y, @room_range );

    # THEN
    is( $has_path, 1, "Path found between two adjacent sectors" );

}

sub test_has_available_path_sector_missing_between_two_points : Tests(1) {
    my $self = shift;

    # GIVEN
    my ( $start_x, $start_y ) = ( 1, 1 );
    my ( $dest_x,  $dest_y )  = ( 1, 3 );
    my @room_range = ( 1, 1, 1, 3 );

    # WHEN
    my $has_path = $self->{dungeon}->_has_available_path( $dest_x, $dest_y, $start_x, $start_y, @room_range );

    # THEN
    is( $has_path, 0, "No path found as intermediate sector missing" );

}

sub test_has_available_path_sector_large_grid : Tests(1) {
    my $self = shift;

    # GIVEN
    my ( $start_x, $start_y ) = ( 1, 1 );
    my ( $dest_x,  $dest_y )  = ( 5, 3 );
    my @room_range = ( 1, 1, 5, 5 );

    my $coords_available;
    for my $x ( 1 .. 5 ) {
        for my $y ( 1 .. 5 ) {
            $coords_available->[$x][$y] = 1;
        }
    }

    # WHEN
    my $has_path = $self->{dungeon}->_has_available_path( $dest_x, $dest_y, $start_x, $start_y, @room_range, $coords_available );

    # THEN
    is( $has_path, 1, "Path found along large grid" );

}

sub test_has_available_path_sector_large_grid_with_row_missing : Tests(1) {
    my $self = shift;

    # GIVEN
    my ( $start_x, $start_y ) = ( 1, 1 );
    my ( $dest_x,  $dest_y )  = ( 5, 3 );
    my @room_range = ( 1, 1, 5, 5 );

    my $coords_available;
    for my $x ( 1 .. 5 ) {
        next if $x == 2;
        for my $y ( 1 .. 5 ) {
            $coords_available->[$x][$y] = 1;
        }
    }

    # WHEN
    my $has_path = $self->{dungeon}->_has_available_path( $dest_x, $dest_y, $start_x, $start_y, @room_range, $coords_available );

    # THEN
    is( $has_path, 0, "No path found as intermediate row missing" );

}

sub test_has_available_two_chunks_missing : Tests(1) {
    my $self = shift;

    # GIVEN
    my ( $start_x, $start_y ) = ( 3, 4 );
    my ( $dest_x,  $dest_y )  = ( 1, 1 );
    my @room_range = ( 1, 1, 3, 4 );

    my $coords_available;
    $coords_available->[1][1] = 1;
    $coords_available->[4][1] = 1;
    $coords_available->[2][1] = 1;
    $coords_available->[2][2] = 1;
    $coords_available->[2][3] = 1;
    $coords_available->[2][4] = 1;
    $coords_available->[3][1] = 1;
    $coords_available->[3][4] = 1;

    # WHEN
    my $has_path = $self->{dungeon}->_has_available_path( $dest_x, $dest_y, $start_x, $start_y, @room_range, $coords_available );

    # THEN
    is( $has_path, 1, "Path found" );

}

sub test_has_available_diagonally_adjacent_chunks_missing : Tests(1) {
    my $self = shift;

    # GIVEN
    my ( $start_x, $start_y ) = ( 3, 6 );
    my ( $dest_x,  $dest_y )  = ( 4, 7 );
    my @room_range = ( 3, 5, 5, 7 );

    my $coords_available;
    $coords_available->[3][6] = 1;
    $coords_available->[4][7] = 1;
    $coords_available->[5][7] = 1;

    # WHEN
    my $has_path = $self->{dungeon}->_has_available_path( $dest_x, $dest_y, $start_x, $start_y, @room_range, $coords_available );

    # THEN
    is( $has_path, 0, "No Path found as dest is only path is diagonal" );

}

sub test_has_available_path_sector_large_grid_with_row_missing_above_start_point : Tests(1) {
    my $self = shift;

    # GIVEN
    my ( $start_x, $start_y ) = ( 15, 16 );
    my ( $dest_x,  $dest_y )  = ( 18, 19 );
    my @room_range = ( 15, 16, 18, 19 );

    my $coords_available;
    for my $x ( 15 .. 18 ) {
        for my $y ( 16 .. 19 ) {
            next if $y == 18;
            $coords_available->[$x][$y] = 1;
        }
    }

    # WHEN
    my $has_path = $self->{dungeon}->_has_available_path( $dest_x, $dest_y, $start_x, $start_y, @room_range, $coords_available );

    # THEN
    is( $has_path, 0, "No path found as intermediate row missing" );

}

1;
