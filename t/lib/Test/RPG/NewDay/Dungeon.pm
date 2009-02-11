use strict;
use warnings;

package Test::RPG::NewDay::Dungeon;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Data::Dumper;

use Test::MockObject;
use Test::More;

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

    use_ok 'RPG::NewDay::Dungeon';

    my $logger = Test::MockObject->new();
    $logger->set_always('debug');
    $RPG::NewDay::Dungeon::logger = $logger;
    $RPG::NewDay::Dungeon::schema = $self->{schema};
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
}
sub test_find_room_dimensions : Tests(no_plan) {
    my $self = shift;

    # GIVEN
    $RPG::NewDay::Dungeon::config = {
        max_x_dungeon_room_size => 6,
        max_y_dungeon_room_size => 6,
    };

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

        my @result = RPG::NewDay::Dungeon->_find_room_dimensions( $test->{start_x}, $test->{start_y} );

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
    $RPG::NewDay::Dungeon::config = {
        max_x_dungeon_room_size => 6,
        max_y_dungeon_room_size => 6,
    };

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
    my @sectors = RPG::NewDay::Dungeon->_create_room( $mock_dungeon, 1, 1, [], $self->{positions} );

    # THEN
    is( scalar @sectors, 9, "9 new sectors created" );

    my $sectors_seen;
    foreach my $sector (@sectors) {
        is( $sector->dungeon_id, 1, "Sector created in correct dungeon" );

        is( defined $expected_sectors->[ $sector->x ][ $sector->y ], 1, "Sector " . $sector->x . ", " . $sector->y . " was expected" );

        my @walls = sort $sector->sides_with_walls;

        my @expected_walls = sort @{ $expected_sectors->[ $sector->x ][ $sector->y ] };

        is_deeply( \@walls, \@expected_walls, "Walls created as expected" );
    }
}

sub test_create_room_with_offset : Test(28) {
    my $self = shift;

    # GIVEN
    $RPG::NewDay::Dungeon::config = {
        max_x_dungeon_room_size => 6,
        max_y_dungeon_room_size => 6,
    };

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
    my @sectors = RPG::NewDay::Dungeon->_create_room( $mock_dungeon, 5, 5, [], $self->{positions});

    # THEN
    is( scalar @sectors, 9, "9 new sectors created" );

    my $sectors_seen;
    foreach my $sector (@sectors) {
        is( $sector->dungeon_id, 1, "Sector created in correct dungeon" );

        is( defined $expected_sectors->[ $sector->x ][ $sector->y ], 1, "Sector " . $sector->x . ", " . $sector->y . " was expected" );

        my @walls = sort $sector->sides_with_walls;

        my @expected_walls = sort @{ $expected_sectors->[ $sector->x ][ $sector->y ] };

        is_deeply( \@walls, \@expected_walls, "Walls created as expected" );
    }
}

sub test_create_room_with_rooms_blocking : Test(17) {
    my $self = shift;

    # GIVEN
    $RPG::NewDay::Dungeon::config = {
        max_x_dungeon_room_size => 6,
        max_y_dungeon_room_size => 6,
    };

    my $mock_dungeon = Test::MockObject->new();
    $mock_dungeon->set_always( 'id', 1 );


    $self->{counter} = 0;
    $self->{rolls} = [ 3, 2, 1, 1 ];

    my @sectors = RPG::NewDay::Dungeon->_create_room( $mock_dungeon, 1, 1, [], $self->{positions} );
    
    is(scalar @sectors, 6, "Sanity check existing room");
    
    my $existing_sectors;
    foreach my $sector (@sectors) {
        $existing_sectors->[$sector->x][$sector->y] = $sector;
    }

    $self->{counter} = 0;
    $self->{rolls} = [ 3, 3, 2, 1 ];

    my $expected_sectors;
    $expected_sectors->[4][1] = [ 'top', 'right', 'left' ];
    $expected_sectors->[4][2] = ['right', 'left'];
    $expected_sectors->[2][3] = ['bottom', 'left', 'top'];
    $expected_sectors->[3][3] = ['bottom', 'top'];
    $expected_sectors->[4][3] = ['bottom', 'right'];


    # WHEN
    @sectors = RPG::NewDay::Dungeon->_create_room( $mock_dungeon, 3, 3, $existing_sectors, $self->{positions});

    # THEN
    is( scalar @sectors, 5, "5 new sectors created" );

    my $sectors_seen;
    foreach my $sector (@sectors) {
        is( $sector->dungeon_id, 1, "Sector created in correct dungeon" );

        is( defined $expected_sectors->[ $sector->x ][ $sector->y ], 1, "Sector " . $sector->x . ", " . $sector->y . " was expected" );

        my @walls = sort $sector->sides_with_walls;

        my @expected_walls = sort @{ $expected_sectors->[ $sector->x ][ $sector->y ] };

        is_deeply( \@walls, \@expected_walls, "Walls created as expected" );
    }
}

sub test_create_door_one_sector_with_no_walls : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $sector = $self->{schema}->resultset('Dungeon_Grid')->create(
        {
            x => 1,
            y => 1,
        }
    );
    
    # WHEN
    my $door = RPG::NewDay::Dungeon->_create_door(
        [$sector],
        [],
        $self->{positions},
    );
    
    # THEN
    is($door, undef, "No door created, since no walls available");
}

sub test_create_door_one_sector_with_one_wall : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $sector = $self->{schema}->resultset('Dungeon_Grid')->create(
        {
            x => 3,
            y => 3,
        }
    );
        
    my $wall = $self->{schema}->resultset('Dungeon_Wall')->create(
        {
            dungeon_grid_id => $sector->id,
            position_id => $self->{positions}{'left'},
        }
    );
    
    # WHEN
    my ($door) = RPG::NewDay::Dungeon->_create_door(
        [$sector],
        [],
        $self->{positions},
    );
    
    # THEN
    is(defined $door, 1, "Door created");
    is($door->position->position, 'left', "Door created in correct position");
}

sub test_create_door_one_in_top_left : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $sector = $self->{schema}->resultset('Dungeon_Grid')->create(
        {
            x => 1,
            y => 1,
        }
    );
        
    my $wall = $self->{schema}->resultset('Dungeon_Wall')->create(
        {
            dungeon_grid_id => $sector->id,
            position_id => $self->{positions}{'left'},
        }
    );
    
    # WHEN
    my ($door) = RPG::NewDay::Dungeon->_create_door(
        [$sector],
        [],
        $self->{positions},
    );
    
    # THEN
    is($door, undef, "Door not created as only wall is top left of map");
}

sub test_create_door_one_sector_with_one_wall_one_existing_door : Tests(1) {
    my $self = shift;
    
    # Given
    my $sector = $self->{schema}->resultset('Dungeon_Grid')->create(
        {
            x => 1,
            y => 1,
        }
    );
        
    my $wall = $self->{schema}->resultset('Dungeon_Wall')->create(
        {
            dungeon_grid_id => $sector->id,
            position_id => $self->{positions}{'left'},
        }
    );
    
    my $existing_door = $self->{schema}->resultset('Door')->create(
        {
            dungeon_grid_id => $sector->id,
            position_id => $self->{positions}{'left'},
        }
    );
    
    # WHEN
    my ($door) = RPG::NewDay::Dungeon->_create_door(
        [$sector],
        [],
        $self->{positions},
    );
    
    is($door, undef, "Door not created as not free wall available");
}

sub test_create_door_one_sector_with_two_walls_one_existing_door : Tests(2) {
    my $self = shift;
    
    # Given
    my $sector = $self->{schema}->resultset('Dungeon_Grid')->create(
        {
            x => 1,
            y => 1,
        }
    );
        
    my $wall1 = $self->{schema}->resultset('Dungeon_Wall')->create(
        {
            dungeon_grid_id => $sector->id,
            position_id => $self->{positions}{'left'},
        }
    );
    
    my $wall2 = $self->{schema}->resultset('Dungeon_Wall')->create(
        {
            dungeon_grid_id => $sector->id,
            position_id => $self->{positions}{'right'},
        }
    );
    
    my $existing_door = $self->{schema}->resultset('Door')->create(
        {
            dungeon_grid_id => $sector->id,
            position_id => $self->{positions}{'left'},
        }
    );
    
    # WHEN
    my ($door) = RPG::NewDay::Dungeon->_create_door(
        [$sector],
        [],
        $self->{positions},
    );
    
    is(defined $door, 1, "Door created");
    is($door->position->position, 'right', "Door created in correct position");
}

sub test_create_door_adjacent_sector_without_joining_door : Tests(5) {
    my $self = shift;
    
    # Given
    my $sector = $self->{schema}->resultset('Dungeon_Grid')->create(
        {
            x => 1,
            y => 1,
        }
    );
    
    # Given
    my $sector2 = $self->{schema}->resultset('Dungeon_Grid')->create(
        {
            x => 1,
            y => 2,
        }
    );
    
    my $existing_sectors;
    $existing_sectors->[1][2] = $sector2;    
        
    my $wall = $self->{schema}->resultset('Dungeon_Wall')->create(
        {
            dungeon_grid_id => $sector->id,
            position_id => $self->{positions}{'bottom'},
        }
    );
    
    # WHEN
    my ($door, $adjacent_door) = RPG::NewDay::Dungeon->_create_door(
        [$sector],
        $existing_sectors,
        $self->{positions},
    );
    
    is(defined $door, 1, "Door created");    
    is($door->position->position, 'bottom', "Door created in correct position");
    is($adjacent_door, 1, "Adjacent door found");
    
    my @doors = $sector2->doors;
    
    is(scalar @doors, 1, "One door created in adjoining sector");
    is($doors[0]->position->position, 'top', "Adjoining door created in correct place");
}

1;
