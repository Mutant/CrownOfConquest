use strict;
use warnings;

package Test::RPG::NewDay::Dungeon;

use base qw(Test::RPG::NewDay::Dungeon::Base);

__PACKAGE__->runtests unless caller();

use Data::Dumper;

use Test::MockObject;
use Test::More;
use Test::Exception;

use Test::RPG::Builder::Dungeon_Room;

sub dungeon_setup : Tests(setup) {
    my $self = shift;

    # Query Dungeon_Positions
    my %positions = map { $_->position => $_->id} $self->{schema}->resultset('Dungeon_Position')->search();

    $self->{positions} = \%positions;

    $self->{config} = {
        max_x_dungeon_room_size => 6,
        max_y_dungeon_room_size => 6,
    };

    $self->{dungeon} = RPG::NewDay::Action::Dungeon->new( context => $self->{context} );
}

sub test_find_room_dimensions : Tests(16) {
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
    undef $self->{rolls};

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

sub test_find_next_corridor_direction_simple : Tests(3) {
    my $self = shift;   
    
    # GIVEN
    my @directions = qw(left right top bottom);
    my $current_direction = 'left';
    my ($x, $y) = (2,2);
    
    # WHEN
    my ($new_direction, $next_x, $next_y) = $self->{dungeon}->_find_next_corridor_direction($current_direction, $x, $y, [], @directions);
    
    # THEN
    is($new_direction, 'left', "Direction unchanged");
    is($next_x, 1, "x decreased by 1");
    is($next_y, 2, "y unchanged");
}

sub test_find_next_corridor_direction_direction_change_needed : Tests(3) {
    my $self = shift;   
    
    # GIVEN
    my @directions = qw(left right top bottom);
    my $current_direction = 'left';
    my ($x, $y) = (2,2);
    my $sectors_created = [];
    $sectors_created->[1][2] = 1;
    
    # WHEN
    my ($new_direction, $next_x, $next_y) = $self->{dungeon}->_find_next_corridor_direction($current_direction, $x, $y, $sectors_created, @directions);
    
    # THEN
    is($new_direction, 'right', "Direction changed");
    is($next_x, 3, "x inreased by 1");
    is($next_y, 2, "y unchanged");
}

sub test_find_next_corridor_direction_no_available_sectors : Tests(3) {
    my $self = shift;   
    
    # GIVEN
    my @directions = qw(left right top bottom);
    my $current_direction = 'left';
    my ($x, $y) = (2,2);
    my $sectors_created = [];
    $sectors_created->[1][2] = 1;
    $sectors_created->[3][2] = 1;
    $sectors_created->[2][1] = 1;
    $sectors_created->[2][3] = 1;
    
    # WHEN
    my ($new_direction, $next_x, $next_y) = $self->{dungeon}->_find_next_corridor_direction($current_direction, $x, $y, $sectors_created, @directions);
    
    # THEN
    is($new_direction, undef, "No direction returned");
    is($next_x, undef, "No x returned");
    is($next_y, undef, "No y returned");
}

sub test_create_walls_for_room : Tests(9) {
    my $self = shift;
    
    # GIVEN
    my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, top_left => {x=>1, y=>1}, bottom_right => {x=>3, y=>3});
    
    my $expected_walls;
    $expected_walls->[1][1] = [qw/left top/];
    $expected_walls->[1][2] = [qw/left/];
    $expected_walls->[1][3] = [qw/bottom left/];
    $expected_walls->[2][1] = [qw/top/];
    $expected_walls->[2][2] = [];
    $expected_walls->[2][3] = [qw/bottom/];
    $expected_walls->[3][1] = [qw/right top/];
    $expected_walls->[3][2] = [qw/right/];
    $expected_walls->[3][3] = [qw/bottom right/];
    
    # WHEN
    $self->{dungeon}->_create_walls_for_room($self->{positions}, $room->sectors);
    
    # THEN
    my @sectors = $room->sectors;
    foreach my $sector (@sectors) {
        is_deeply([sort $sector->sides_with_walls], $expected_walls->[$sector->x][$sector->y], "Correct walls for sector: " . $sector->x . ', ' . $sector->y)
            || diag explain [sort $sector->sides_with_walls];   
    }    
}

sub test_create_corridor : Tests(1) {
    my $self = shift;
    
    # GIVEN
    $self->{counter} = 0;
    $self->{rolls} = [12, 2, 2, 2, 2];

    my $mock_dungeon = Test::MockObject->new();
    $mock_dungeon->set_always( 'id', 88 );
    
    # WHEN
    my @sectors = $self->{dungeon}->_create_corridor($mock_dungeon, 10, 10, [], $self->{positions});
    
    # THEN
    is(scalar @sectors, 20, "Correct number of sectors created");

    
       
}

1;
