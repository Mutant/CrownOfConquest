use strict;
use warnings;

package Test::RPG::NewDay::Creatures;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Data::Dumper;

use Test::MockObject;
use Test::More;

use RPG::Ticker::LandGrid;

use Test::RPG::Builder::CreatureType;
use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Dungeon_Room;
use Test::RPG::Builder::CreatureGroup;

sub setup_creature_data : Test(startup=>1) {
    my $self = shift;

    my $logger = Test::MockObject->new();
    $logger->set_true('warning');
    $logger->set_true('info');
    $logger->set_true('debug');

    $self->{logger} = $logger;

    $self->{context} = Test::MockObject->new();
    $self->{context}->set_always( 'logger', $logger );
    $self->{context}->set_always( 'schema', $self->{schema} );
    $self->{context}->mock( 'config',    sub { $self->{config} } );
    $self->{context}->mock( 'land_grid', sub { $self->{land_grid} } );
    $self->{context}->set_isa('RPG::NewDay::Context');

    use_ok('RPG::NewDay::Action::Creatures');

    $self->{creature_action} = RPG::NewDay::Action::Creatures->new( context => $self->{context} );
}

sub setup_creature_config : Test(setup) {
    my $self = shift;

    $self->{config} = {
        creature_groups_to_parties     => 5,
        max_creature_groups_per_sector => 1,
        min_creature_groups_per_sector => 0,
        max_hops                       => 2,
    };

    $self->{cret_category} = $self->{schema}->resultset('Creature_Category')->create(
        {
            name => 'Test',
        },
    );

    $self->{creature_type_1} = $self->{schema}->resultset('CreatureType')->create(
        {
            creature_type        => 'creature type',
            level                => 1,
            creature_category_id => $self->{cret_category}->id,
        }
    );

    $self->{creature_type_2} = $self->{schema}->resultset('CreatureType')->create(
        {
            creature_type        => 'creature type',
            level                => 2,
            creature_category_id => $self->{cret_category}->id,
        }
    );

    $self->{creature_type_3} = $self->{schema}->resultset('CreatureType')->create(
        {
            creature_type        => 'creature type',
            level                => 3,
            creature_category_id => $self->{cret_category}->id,
        }
    );
}

sub test_spawn_monsters : Tests(4) {
    my $self = shift;

    my @land = $self->_create_land();

    # Orb in top left
    $self->{schema}->resultset('Creature_Orb')->create( { land_id => $land[0]->id, level => 1 } );

    # Create a party to force some monsters to be generated
    $self->{schema}->resultset('Party')->create( {} );

    $self->{land_grid} = RPG::Ticker::LandGrid->new( schema => $self->{schema} );

    $self->{creature_action}->spawn_monsters;

    my @cgs = $self->{schema}->resultset('CreatureGroup')->search( {}, { prefetch => 'location', } );
    is( scalar @cgs, 5, "Five groups generated" );

    # Find out the distance of each cg from the orb. 3 should be 1 sector, 1 should be 2 sectors
    my %distance;
    foreach my $cg (@cgs) {
        my $dist = RPG::Map->get_distance_between_points(
            {
                x => $land[0]->x,
                y => $land[0]->y,
            },
            {
                x => $cg->location->x,
                y => $cg->location->y,
            }
        );

        $distance{$dist}++;
    }

    is( $distance{0}, 1, "1 cgs 0 square from the orb" );
    is( $distance{1}, 3, "3 cgs 1 square from the orb" );
    is( $distance{2}, 1, "1 cgs 2 squares from the orb" );
}

sub test_spawn_monsters_multiple_orbs : Tests(9) {
    my $self = shift;

    my @land = $self->_create_land();

    # Orb in top left
    my $orb1 = $self->{schema}->resultset('Creature_Orb')->create( { land_id => $land[0]->id, level => 1 } );

    # Orb in top right
    my $orb2 = $self->{schema}->resultset('Creature_Orb')->create( { land_id => $land[2]->id, level => 1 } );

    # Create a party to force some monsters to be generated
    $self->{schema}->resultset('Party')->create( {} );

    $self->{config}{creature_groups_to_parties} = 4;

    $self->{land_grid} = RPG::Ticker::LandGrid->new( schema => $self->{schema} );

    $self->{creature_action}->spawn_monsters;

    my @cgs = $self->{schema}->resultset('CreatureGroup')->search( {}, { prefetch => 'location', } );
    is( scalar @cgs, 4, "4 groups generated" );

    # Make sure all 6 groups are in different squares, and all 1 square away from an orb, or on the orb itself
    my %land_ids_used;
    foreach my $cg (@cgs) {
        isnt( $land_ids_used{ $cg->location->id }, 1, "Land id not already used" );

        $land_ids_used{ $cg->location->id } = 1;

        if ( $orb1->land_id == $cg->land_id || $orb2->land_id == $cg->land_id ) {
            pass("CG spawned on the orb");
            next;
        }

        my $adjacent_to_orb;

        #warn "checking cg: " . $cg->location->x . ", " . $cg->location->y;

        for my $orb ( $orb1, $orb2 ) {

            #warn "orb: " . $orb->land->x . ", " . $orb->land->y;
            $adjacent_to_orb = RPG::Map->is_adjacent_to(
                {
                    x => $cg->location->x,
                    y => $cg->location->y,
                },
                {
                    x => $orb->land->x,
                    y => $orb->land->y,
                }
            );
            last if $adjacent_to_orb;
        }

        is( $adjacent_to_orb, 1, "Group spawned adjacent to orb" );

    }

}

sub test_spawn_monsters_with_towns : Tests(2) {
    my $self = shift;

    my @land = $self->_create_land();

    # Orb in top left
    $self->{schema}->resultset('Creature_Orb')->create( { land_id => $land[0]->id, level => 1 } );

    # Town next to Orb
    $self->{schema}->resultset('Town')->create( { land_id => $land[1]->id } );

    # Create a party to force some monsters to be generated
    $self->{schema}->resultset('Party')->create( {} );

    $self->{config}{creature_groups_to_parties} = 3;

    $self->{land_grid} = RPG::Ticker::LandGrid->new( schema => $self->{schema} );

    $self->{creature_action}->spawn_monsters;

    my @cgs = $self->{schema}->resultset('CreatureGroup')->search( {}, { prefetch => 'location', } );
    is( scalar @cgs, 3, "3 groups generated" );

    # Check if any spawned in the town
    my $spawned_in_town = 0;
    foreach my $cg (@cgs) {
        if ( $cg->land_id == $land[1]->id ) {
            $spawned_in_town = 1;
            last;
        }
    }

    is( $spawned_in_town, 0, "No groups were spawned in town" );
}

sub test_move_cg_no_other_cgs : Tests(3) {
    my $self = shift;

    my @land = $self->_create_land();

    my $cg = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[0]->id, }, );

    $self->{land_grid} = RPG::Ticker::LandGrid->new( schema => $self->{schema} );

    my $moved = $self->{creature_action}->_move_cg( 1, $cg );

    is( defined $moved, 1, "Creature group was moved" );

    $cg->discard_changes;
    isnt( $cg->land_id, $land[0]->id, "No longer in the same position" );
    is(
        RPG::Map->is_adjacent_to(
            {
                x => $cg->location->x,
                y => $cg->location->y,
            },
            {
                x => $land[0]->x,
                y => $land[0]->y,
            }
        ),
        1,
        "New land is adjacent to old land",
    );
}

sub test_move_cg_some_other_cgs : Tests(2) {
    my $self = shift;

    my @land = $self->_create_land();

    my $cg1 = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[0]->id, }, );
    my $cg2 = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[1]->id, }, );
    my $cg3 = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[3]->id, }, );

    $self->{land_grid} = RPG::Ticker::LandGrid->new( schema => $self->{schema} );

    my $moved = $self->{creature_action}->_move_cg( 1, $cg1 );

    is( defined $moved, 1, "Creature group was moved" );

    $cg1->discard_changes;
    is( $cg1->land_id, $land[4]->id, "Moved to only sector available" );
}

sub test_move_cg_other_cgs_blocking : Tests(2) {
    my $self = shift;

    my @land = $self->_create_land();

    my $cg1 = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[0]->id, }, );
    my $cg2 = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[1]->id, }, );
    my $cg3 = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[3]->id, }, );
    my $cg4 = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[4]->id, }, );

    $self->{land_grid} = RPG::Ticker::LandGrid->new( schema => $self->{schema} );

    my $moved = $self->{creature_action}->_move_cg( 1, $cg1 );

    is( defined $moved, '', "Creature group was not moved" );

    $cg1->discard_changes;
    is( $cg1->land_id, $land[0]->id, "Still in the same position" );
}

sub test_move_cg_ctr_blocks_some_squares : Tests(2) {
    my $self = shift;

    my @land = $self->_create_land();

    $self->mock_dice();
    $self->{roll_result} = -1;

    my $cg = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[4]->id, }, );
    my $creature_type = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 5 );
    my $creature = $self->{schema}->resultset('Creature')->create(
        {
            creature_type_id  => $creature_type->id,
            creature_group_id => $cg->id,
        }
    );

    # Make one land low enough CTR to move
    $land[5]->creature_threat(20);
    $land[5]->update;

    $self->{land_grid} = RPG::Ticker::LandGrid->new( schema => $self->{schema} );

    my $moved = $self->{creature_action}->_move_cg( 1, $cg );

    is( defined $moved, 1, "Creature group was moved" );

    $cg->discard_changes;
    is( $cg->land_id, $land[5]->id, "Moved to only sector available" );

    $self->unmock_dice();
}

sub test_move_cg_ctr_blocks_all_squares : Tests(2) {
    my $self = shift;

    my @land = $self->_create_land();

    $self->mock_dice();
    $self->{roll_result} = 1;

    my $cg = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[4]->id, }, );
    my $creature_type = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 8 );
    my $creature = $self->{schema}->resultset('Creature')->create(
        {
            creature_type_id  => $creature_type->id,
            creature_group_id => $cg->id,
        }
    );

    $self->{land_grid} = RPG::Ticker::LandGrid->new( schema => $self->{schema} );

    my $moved = $self->{creature_action}->_move_cg( 1, $cg );

    is( defined $moved, '', "Creature group was not moved" );

    $cg->discard_changes;
    is( $cg->land_id, $land[4]->id, "Still in the same square" );

    $self->unmock_dice();
}

sub test_move_cg_ctr_blocks_all_adjacent_squares_but_hop_allowed : Tests(2) {
    my $self = shift;

    # GIVEN
    $self->mock_dice();
    $self->{roll_result} = -1;

    my @land = $self->_create_land( 5, 5 );

    my $cg = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[12]->id, }, );
    my $creature_type = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 5 );
    my $creature = $self->{schema}->resultset('Creature')->create(
        {
            creature_type_id  => $creature_type->id,
            creature_group_id => $cg->id,
        }
    );

    # Make one land high enough CTR to move
    $land[0]->creature_threat(20);
    $land[0]->update;

    $self->{land_grid} = RPG::Ticker::LandGrid->new( schema => $self->{schema} );

    # WHEN
    my $moved = $self->{creature_action}->_move_cg( 2, $cg );

    # THEN
    is( defined $moved, 1, "Creature group was moved" );

    $cg->discard_changes;
    is( $cg->land_id, $land[0]->id, "Hopped to available sqaure" );

    $self->unmock_dice();
}

sub test_move_multiple_cgs_second_one_blocked : Tests(4) {
    my $self = shift;

    $self->mock_dice();
    $self->{roll_result} = -1;

    my @land = $self->_create_land();

    my $cg1 = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[3]->id, }, );
    my $cg2 = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[4]->id, }, );
    my $creature_type = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 5 );
    my $creature1 = $self->{schema}->resultset('Creature')->create(
        {
            creature_type_id  => $creature_type->id,
            creature_group_id => $cg1->id,
        }
    );
    my $creature2 = $self->{schema}->resultset('Creature')->create(
        {
            creature_type_id  => $creature_type->id,
            creature_group_id => $cg2->id,
        }
    );

    # Make one land high enough CTR to move
    $land[0]->creature_threat(20);
    $land[0]->update;

    $self->{land_grid} = RPG::Ticker::LandGrid->new( schema => $self->{schema} );

    my $moved = $self->{creature_action}->_move_cg( 2, $cg1 );

    is( defined $moved, 1, "First creature group was moved" );

    $cg1->discard_changes;
    is( $cg1->land_id, $land[0]->id, "Moved to available sqaure" );

    $moved = $self->{creature_action}->_move_cg( 1, $cg2 );

    is( defined $moved, '', "Second creature group was not moved" );

    $cg2->discard_changes;
    is( $cg2->land_id, $land[4]->id, "Still in the same sqaure" );

    $self->unmock_dice;
}

sub test_move_cg_town_blocks_some_squares : Tests(2) {
    my $self = shift;

    my @land = $self->_create_land();

    my $cg = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[0]->id, }, );

    # Block cg in with towns
    for my $idx ( 1 .. 4 ) {
        $self->{schema}->resultset('Town')->create( { land_id => $land[$idx]->id, }, );
    }

    $self->{land_grid} = RPG::Ticker::LandGrid->new( schema => $self->{schema} );

    my $moved = $self->{creature_action}->_move_cg( 1, $cg );

    is( defined $moved, '', "Creature group couldn't be moved" );

    $cg->discard_changes;
    is( $cg->land_id, $land[0]->id, "Still in same sector" );
}

sub test_move_monsters : Tests(4) {
    my $self = shift;

    $self->mock_dice();
    $self->{roll_result} = -1;

    my @land = $self->_create_land( 4, 4 );

    my $cg1 = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[0]->id, }, );
    my $cg2 = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[5]->id, }, );
    my $creature_type = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 5 );
    my $creature1 = $self->{schema}->resultset('Creature')->create(
        {
            creature_type_id  => $creature_type->id,
            creature_group_id => $cg1->id,
        }
    );
    my $creature2 = $self->{schema}->resultset('Creature')->create(
        {
            creature_type_id  => $creature_type->id,
            creature_group_id => $cg2->id,
        }
    );

    # Make land where second cg is high enough to move
    $land[5]->creature_threat(20);
    $land[5]->update;

    # Make land where second cg can move
    $land[15]->creature_threat(20);
    $land[15]->update;

    $self->{config}{creature_move_chance} = 100;    # Always move cgs

    $self->{land_grid} = RPG::Ticker::LandGrid->new( schema => $self->{schema} );

    $self->{creature_action}->move_monsters();

    $cg1->discard_changes;
    $cg2->discard_changes;
    is( $cg1->location->x, $land[5]->x, "First cg moved to x where second was" );
    is( $cg1->location->y, $land[5]->y, "First cg moved to y where second was" );
    is( $cg2->location->x, $land[15]->x, "Second cg moved to x available square" );
    is( $cg2->location->y, $land[15]->y, "Second cg moved to y available square" );

    $self->unmock_dice;

}

sub _create_land {
    my $self   = shift;
    my $x_size = shift || 3;
    my $y_size = shift || 3;

    my $non_town_terrain = $self->{schema}->resultset('Terrain')->create( { terrain_name => 'non_town_terrain', } );

    $self->{town_terrain} = $self->{schema}->resultset('Terrain')->create( { terrain_name => 'town', } );

    my @land;
    for my $x ( 1 .. $x_size ) {
        for my $y ( 1 .. $y_size ) {
            push @land, $self->{schema}->resultset('Land')->create(
                {
                    x               => $x,
                    y               => $y,
                    terrain_id      => $non_town_terrain->id,
                    creature_threat => -80,
                }
            );
        }
    }

    return @land;
}

sub test_move_dungeon_monsters : Tests(1) {
    my $self = shift;

    # GIVEN
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );
    my $room1 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema},
        dungeon_id => $dungeon->id,
        top_left   => {
            x => 1,
            y => 1,
        },
        bottom_right => {
            x => 1,
            y => 1,
        },
        create_walls => 1,
        sector_doors => {
            '1,1' => 'bottom',
        },
    );
    my $room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema},
        dungeon_id => $dungeon->id,
        top_left   => {
            x => 1,
            y => 2,
        },
        bottom_right => {
            x => 1,
            y => 2,
        },
        create_walls => 1,
        sector_doors => {
            '1,2' => 'top',
        },
    );
    $dungeon->populate_sector_paths;

    my ($sector1) = $room1->sectors;
    my ($sector2) = $room2->sectors;

    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, dungeon_grid_id => $sector1->id );

    $self->{config}{creature_move_chance} = 100;

    # WHEN
    $self->{creature_action}->move_dungeon_monsters();

    # THEN
    $cg->discard_changes;
    is( $cg->dungeon_grid_id, $sector2->id, "CG moved" );
}

sub test_spawn_in_dungeon : Tests(1) {
    my $self = shift;

    # GIVEN
    my $creature_type1 = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 1 );
    my $creature_type2 = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 2 );
    my $creature_type3 = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 3 );
    my $creature_type4 = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 4 );
    my $creature_type5 = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 5 );
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );
    my $room1 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema},
        dungeon_id => $dungeon->id,
        top_left   => {
            x => 1,
            y => 1,
        },
        bottom_right => {
            x => 3,
            y => 3,
        },
        create_walls => 1,
    );
    my $room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema},
        dungeon_id => $dungeon->id,
        top_left   => {
            x => 4,
            y => 1,
        },
        bottom_right => {
            x => 6,
            y => 3,
        },
        create_walls => 1,
    );

    # WHEN
    $self->{creature_action}->_spawn_in_dungeon( $self->{context}, $dungeon, 5 );

    # THEN
    my $cg_count = $self->{schema}->resultset('CreatureGroup')->search(
        { 'dungeon_room.dungeon_id' => $dungeon->dungeon_id, },
        { join => { 'dungeon_grid' => 'dungeon_room' }, }
    )->count;
    is( $cg_count, 3, "3 CGs generated" );

}

1;
