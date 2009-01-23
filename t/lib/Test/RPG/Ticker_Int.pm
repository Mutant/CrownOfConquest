use strict;
use warnings;

package Test::RPG::Ticker_Int;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Data::Dumper;

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Character;

use RPG::Ticker;

sub setup_data : Test(startup) {
    my $self = shift;

    my $logger = Test::MockObject->new();
    $logger->set_true('warning');
    $logger->set_true('info');
    $logger->set_true('debug');

    $self->{logger} = $logger;
}

sub setup : Test(setup) {
    my $self = shift;

    $self->{config} = {
        land_per_orb                     => 4,
        orb_distance_from_town_per_level => 2,
        min_orb_level_cg                 => 2,
        max_orb_level_cg                 => 3,
        creature_groups_to_parties       => 5,
        max_creature_groups_per_sector   => 1,
        min_creature_groups_per_sector   => 0,
        max_hops                         => 2,
        max_orb_level                    => 1,
        orb_distance_from_other_orb      => 2,
    };

    $self->{creature_type_1} = $self->{schema}->resultset('CreatureType')->create(
        {
            creature_type => 'creature type',
            level         => 1,
        }
    );

    $self->{creature_type_2} = $self->{schema}->resultset('CreatureType')->create(
        {
            creature_type => 'creature type',
            level         => 2,
        }
    );

    $self->{creature_type_3} = $self->{schema}->resultset('CreatureType')->create(
        {
            creature_type => 'creature type',
            level         => 3,
        }
    );
}

sub test_spawn_orbs_successful_run : Tests(7) {
    my $self = shift;

    my @land = $self->_create_land();

    # Towns on top left and bottom right corners
    for my $idx ( 0, 8 ) {
        $self->{schema}->resultset('Town')->create( { 'land_id' => $land[$idx]->id } );
    }

    RPG::Ticker->spawn_orbs( $self->{config}, $self->{schema}, $self->{logger} );

    my @orbs = $self->{schema}->resultset('Creature_Orb')->search(
        {},
        {
            order_by => 'x,y',
            prefetch => 'land',
        }
    );

    is( scalar @orbs,                           2, "Should be two orbs" );
    is( $orbs[0]->land->x,                      1, "First orb should be at x=1" );
    is( $orbs[0]->land->y,                      3, "First orb should be at y=3" );
    is( defined $orbs[0]->land->creature_group, 1, "Creature group spawned at first orb" );

    is( $orbs[1]->land->x,                      3, "Second orb should be at x=3" );
    is( $orbs[1]->land->y,                      1, "Second orb should be at y=1" );
    is( defined $orbs[1]->land->creature_group, 1, "Creature group spawned at second orb" );
}

sub test_spawn_orb_successful_run_with_existing_orb : Test(2) {
    my $self = shift;

    my @land = $self->_create_land();

    # Town on top left corner
    $self->{schema}->resultset('Town')->create( { 'land_id' => $land[0]->id } );

    $self->{schema}->resultset('Creature_Orb')->create( { land_id => $land[2]->id, } );

    RPG::Ticker->spawn_orbs( $self->{config}, $self->{schema}, $self->{logger} );

    my @orbs = $self->{schema}->resultset('Creature_Orb')->search(
        {},
        {
            order_by => 'x,y',
            prefetch => 'land',
        }
    );

    is( scalar @orbs,      2, "Should be two orbs" );
    is( $orbs[1]->land->x, 3, "Second orb created on bottom row" );

}

sub test_spawn_orbs_successful_run_with_existing_cg : Tests(8) {
    my $self = shift;

    my @land = $self->_create_land();

    # Towns on top left and bottom right corners
    for my $idx ( 0, 8 ) {
        $self->{schema}->resultset('Town')->create( { 'land_id' => $land[$idx]->id } );
    }

    my $existing_cg = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[2]->id, }, );

    RPG::Ticker->spawn_orbs( $self->{config}, $self->{schema}, $self->{logger} );

    my @orbs = $self->{schema}->resultset('Creature_Orb')->search(
        {},
        {
            order_by => 'x,y',
            prefetch => 'land',
        }
    );

    is( scalar @orbs,      2, "Should be two orbs" );
    is( $orbs[0]->land->x, 1, "First orb should be at x=1" );
    is( $orbs[0]->land->y, 3, "First orb should be at y=3" );

    my @spawned_cgs = $orbs[0]->land->search_related('creature_group');

    is( scalar @spawned_cgs, 1, "Creature group spawned at first orb" );
    is( $spawned_cgs[0]->id, $existing_cg->id, "Didn't spawn a new cg, as one already there" );

    is( $orbs[1]->land->x, 3, "Second orb should be at x=3" );
    is( $orbs[1]->land->y, 1, "Second orb should be at y=1" );

    @spawned_cgs = $orbs[1]->land->search_related('creature_group');
    is( scalar @spawned_cgs, 1, "Creature group spawned at first orb" );
}

sub test_spawn_orb_with_town_search_smaller_than_orb_search : Test(1) {
    my $self = shift;

    my @land = $self->_create_land( 5, 5 );

    $self->{schema}->resultset('Creature_Orb')->create( { land_id => $land[12]->id, } );

    $self->{config}->{orb_distance_from_other_orb} = 3;

    RPG::Ticker->spawn_orbs( $self->{config}, $self->{schema}, $self->{logger} );

    my @orbs = $self->{schema}->resultset('Creature_Orb')->search(
        {},
        {
            order_by => 'x,y',
            prefetch => 'land',
        }
    );

    is( scalar @orbs, 1, "Should only be one orb" );

}

sub test_spawn_orb_no_room_for_new_orb : Test(2) {
    my $self = shift;

    my @land = $self->_create_land();

    for my $idx ( 0, 4, 8 ) {
        $self->{schema}->resultset('Town')->create( { 'land_id' => $land[$idx]->id } );
    }

    RPG::Ticker->spawn_orbs( $self->{config}, $self->{schema}, $self->{logger} );

    my @orbs = $self->{schema}->resultset('Creature_Orb')->search(
        {},
        {
            order_by => 'x,y',
            prefetch => 'land',
        }
    );

    is( scalar @orbs, 0, "Should be no orbs" );
    $self->{logger}->called_ok( 'warning', "Warning should be written to log file" );
}

sub test_spawn_monsters : Tests(4) {
    my $self = shift;

    my @land = $self->_create_land();

    # Orb in top left
    $self->{schema}->resultset('Creature_Orb')->create( { land_id => $land[0]->id, level => 1 } );

    # Create a party to force some monsters to be generated
    $self->{schema}->resultset('Party')->create( {} );

    RPG::Ticker->spawn_monsters( $self->{config}, $self->{schema}, $self->{logger} );

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

sub test_spawn_monsters_multiple_orbs : Tests(13) {
    my $self = shift;

    my @land = $self->_create_land();

    # Orb in top left
    my $orb1 = $self->{schema}->resultset('Creature_Orb')->create( { land_id => $land[0]->id, level => 1 } );

    # Orb in top right
    my $orb2 = $self->{schema}->resultset('Creature_Orb')->create( { land_id => $land[2]->id, level => 1 } );

    # Create a party to force some monsters to be generated
    $self->{schema}->resultset('Party')->create( {} );

    $self->{config}{creature_groups_to_parties} = 6;

    RPG::Ticker->spawn_monsters( $self->{config}, $self->{schema}, $self->{logger} );

    my @cgs = $self->{schema}->resultset('CreatureGroup')->search( {}, { prefetch => 'location', } );
    is( scalar @cgs, 6, "6 groups generated" );

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

    RPG::Ticker->spawn_monsters( $self->{config}, $self->{schema}, $self->{logger} );

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

    my $moved = RPG::Ticker->_move_cg( $self->{schema}, 3, $cg );

    is( $moved, 1, "Creature group was moved" );

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

    my $moved = RPG::Ticker->_move_cg( $self->{schema}, 3, $cg1 );

    is( $moved, 1, "Creature group was moved" );

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

    my $moved = RPG::Ticker->_move_cg( $self->{schema}, 3, $cg1 );

    is( $moved, 0, "Creature group was not moved" );

    $cg1->discard_changes;
    is( $cg1->land_id, $land[0]->id, "Still in the same position" );
}

sub test_move_cg_ctr_blocks_some_squares : Tests(2) {
    my $self = shift;

    my @land = $self->_create_land();

    my $cg = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[4]->id, }, );
    my $creature = $self->{schema}->resultset('Creature')->create(
        {
            creature_type_id  => $self->{creature_type_2}->id,
            creature_group_id => $cg->id,
        }
    );

    # Make one land high enough CTR to move
    $land[5]->creature_threat(20);
    $land[5]->update;

    my $moved = RPG::Ticker->_move_cg( $self->{schema}, 3, $cg );

    is( $moved, 1, "Creature group was moved" );

    $cg->discard_changes;
    is( $cg->land_id, $land[5]->id, "Moved to only sector available" );
}

sub test_move_cg_ctr_blocks_all_squares : Tests(2) {
    my $self = shift;

    my @land = $self->_create_land();

    my $cg = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[4]->id, }, );
    my $creature = $self->{schema}->resultset('Creature')->create(
        {
            creature_type_id  => $self->{creature_type_2}->id,
            creature_group_id => $cg->id,
        }
    );

    my $moved = RPG::Ticker->_move_cg( $self->{schema}, 3, $cg );

    is( $moved, 0, "Creature group was not moved" );

    $cg->discard_changes;
    is( $cg->land_id, $land[4]->id, "Still in the same square" );
}

sub test_move_cg_ctr_blocks_all_adjacent_squares_but_hop_allowed : Tests(2) {
    my $self = shift;

    my @land = $self->_create_land( 5, 5 );

    my $cg = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[12]->id, }, );
    my $creature = $self->{schema}->resultset('Creature')->create(
        {
            creature_type_id  => $self->{creature_type_2}->id,
            creature_group_id => $cg->id,
        }
    );

    # Make one land high enough CTR to move
    $land[0]->creature_threat(20);
    $land[0]->update;

    my $moved = RPG::Ticker->_move_cg( $self->{schema}, 5, $cg );

    is( $moved, 1, "Creature group was moved" );

    $cg->discard_changes;
    is( $cg->land_id, $land[0]->id, "Hopped to available sqaure" );
}

sub test_move_multiple_cgs_second_one_blocked : Tests(4) {
    my $self = shift;

    my @land = $self->_create_land();

    my $cg1 = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[3]->id, }, );
    my $cg2 = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[4]->id, }, );
    my $creature1 = $self->{schema}->resultset('Creature')->create(
        {
            creature_type_id  => $self->{creature_type_2}->id,
            creature_group_id => $cg1->id,
        }
    );
    my $creature2 = $self->{schema}->resultset('Creature')->create(
        {
            creature_type_id  => $self->{creature_type_2}->id,
            creature_group_id => $cg2->id,
        }
    );

    # Make one land high enough CTR to move
    $land[0]->creature_threat(20);
    $land[0]->update;

    my $moved = RPG::Ticker->_move_cg( $self->{schema}, 3, $cg1 );

    is( $moved, 1, "First creature group was moved" );

    $cg1->discard_changes;
    is( $cg1->land_id, $land[0]->id, "Moved to available sqaure" );

    $moved = RPG::Ticker->_move_cg( $self->{schema}, 3, $cg2 );

    is( $moved, 0, "Second creature group was not moved" );

    $cg2->discard_changes;
    is( $cg2->land_id, $land[4]->id, "Still in the same sqaure" );
}

sub test_move_cg_town_blocks_some_squares : Tests(2) {
    my $self = shift;

    my @land = $self->_create_land();

    my $cg = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[0]->id, }, );

    # Block cg in with towns
    for my $idx ( 1 .. 4 ) {
        $self->{schema}->resultset('Town')->create( { land_id => $land[$idx]->id, }, );
    }

    my $moved = RPG::Ticker->_move_cg( $self->{schema}, 3, $cg );

    is( $moved, 0, "Creature group couldn't be moved" );

    $cg->discard_changes;
    is( $cg->land_id, $land[0]->id, "Still in same sector" );
}

sub test_move_monsters : Tests(2) {
    my $self = shift;

    my @land = $self->_create_land( 4, 4 );

    my $cg1 = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[0]->id, }, );
    my $cg2 = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[5]->id, }, );
    my $creature1 = $self->{schema}->resultset('Creature')->create(
        {
            creature_type_id  => $self->{creature_type_2}->id,
            creature_group_id => $cg1->id,
        }
    );
    my $creature2 = $self->{schema}->resultset('Creature')->create(
        {
            creature_type_id  => $self->{creature_type_2}->id,
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

    RPG::Ticker->move_monsters( $self->{config}, $self->{schema}, $self->{logger} );

    $cg1->discard_changes;
    $cg2->discard_changes;
    is( $cg1->land_id, $land[5]->id,  "First cg moved to where second was" );
    is( $cg2->land_id, $land[15]->id, "Second cg moved to available square" );

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
                    creature_threat => 10,
                }
            );
        }
    }

    return @land;
}

1;
