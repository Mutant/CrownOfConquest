use strict;
use warnings;

package Test::RPG::Schema::Land;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::More;
use Test::MockObject;
use Test::Exception;

use Test::RPG::Builder::CreatureGroup;
use Test::RPG::Builder::Land;
use Test::RPG::Builder::Town;

use RPG::Schema::Land;

sub test_next_to : Tests(5) {
    my $self = shift;

    my @tests = (
        {
            sectors => [ { x => 1, y => 2 }, { x => 3, y => 4 }, ],
            result  => 0,
            desc    => 'Sectors not next to each other',
        },
        {
            sectors => [ { x => 1, y => 1 }, { x => 1, y => 2 }, ],
            result  => 1,
            desc    => 'Sector to the right',
        },
        {
            sectors => [ { x => 100, y => 100 }, { x => 101, y => 100 }, ],
            result  => 1,
            desc    => 'Sector below',
        },
        {
            sectors => [ { x => 1, y => 1 }, { x => 2, y => 2 }, ],
            result  => 1,
            desc    => 'Sector on the diagonal',
        },
        {
            sectors => [ { x => 5, y => 5 }, { x => 5, y => 5 }, ],
            result  => 0,
            desc    => 'Sectors the same, not next to',
        },
    );

    foreach my $test (@tests) {
        my @sectors;

        foreach my $sector ( @{ $test->{sectors} } ) {
            my $mock_sector = Test::MockObject->new;
            $mock_sector->set_always( 'x', $sector->{x} );
            $mock_sector->set_always( 'y', $sector->{y} );
            push @sectors, $mock_sector;
        }

        is( RPG::Schema::Land::next_to(@sectors), $test->{result}, $test->{desc} );
    }
}

sub test_movement_cost : Tests(5) {
    my $self = shift;

    throws_ok(
        sub { RPG::Schema::Land::movement_cost('package') },
        qr|movement factor not supplied|,
        "Exception thrown if movement factor not passed",
    );

    my @tests = (
        {
            modifier      => 25,
            movement_cost => 10,
            result        => 15,
            desc          => 'basic test',
        },
        {
            modifier      => 5,
            movement_cost => 6,
            result        => 1,
            desc          => 'movement cost never less than 1',
        },
    );

    foreach my $test (@tests) {
        my $mock_terrain = Test::MockObject->new;
        $mock_terrain->set_always( 'modifier', $test->{modifier} );

        my $mock_sector = Test::MockObject->new;
        $mock_sector->set_always( 'terrain', $mock_terrain );

        is( RPG::Schema::Land::movement_cost( $mock_sector, $test->{movement_cost} ), $test->{result}, "movement_cost: " . $test->{desc} );

        is( RPG::Schema::Land::movement_cost( 'package', $test->{movement_cost}, $test->{modifier} ),
            $test->{result}, "movement_cost (as class method): " . $test->{desc} );
    }
}

sub test_available_creature_group : Tests(1) {
    my $self = shift;

    my $land = $self->{schema}->resultset('Land')->create( {} );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, land_id => $land->id );

    my $cg_found = $land->available_creature_group;

    is( $cg_found->id, $cg->id, "CG found correctly" );
}

sub test_available_creature_group_creatures_all_dead : Tests(1) {
    my $self = shift;

    my $land = $self->{schema}->resultset('Land')->create( {} );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, land_id => $land->id, creature_hit_points_current => 0 );

    my $cg_found = $land->available_creature_group;

    is( $cg_found, undef, "No cg returned, since creatures are all dead" );
}

sub test_available_creature_group_cg_in_combat : Tests(1) {
    my $self = shift;

    my $land = $self->{schema}->resultset('Land')->create( {} );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, land_id => $land->id );
    my $party = $self->{schema}->resultset('Party')->create( { in_combat_with => $cg->id } );

    my $cg_found = $land->available_creature_group;

    is( $cg_found, undef, "No cg found, since it's in combat" );
}

sub test_get_adjacent_towns_none_nearby : Tests(9) {
    my $self = shift;
    
    my @land = Test::RPG::Builder::Land->build_land($self->{schema});
    
    foreach my $land (@land) {
        is($land->get_adjacent_towns, 0, "No towns near by");   
    }   
}

sub test_get_adjacent_towns_one_nearby : Tests(12) {
    my $self = shift;
    
    my @land = Test::RPG::Builder::Land->build_land($self->{schema});
    
    my $town = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $land[0]->id);
    
    foreach my $idx (0,2,5,6,7,8) {
        is($land[$idx]->get_adjacent_towns, 0, "No towns near by (idx: $idx)");   
    }

    foreach my $idx (1,3,4) {
        my @towns = $land[$idx]->get_adjacent_towns;
        is(scalar @towns, 1, "Correct number of towns");
        is($towns[0]->id, $town->id, "Town near by (idx: $idx)");   
    }
}

sub test_has_road_joining_to_not_adjacent : Tests(1) {
    my $self = shift;   
    
    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land($self->{schema});

    # WHEN
    my $result = $land[0]->has_road_joining_to($land[8]);
    
    # THEN
    is($result, 0, "Roads do not join sectors");
    
}

sub test_has_road_joining_to_roads_join : Tests(1) {
    my $self = shift;   
    
    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land($self->{schema});
    
    $self->{schema}->resultset('Road')->create(
        {
            position => 'bottom right',  
            land_id => $land[0]->id,
        },
    );

    $self->{schema}->resultset('Road')->create(
        {
            position => 'top left',  
            land_id => $land[4]->id,
        },
    );

    # WHEN
    my $result = $land[0]->has_road_joining_to($land[4]);
    
    # THEN
    is($result, 1, "Roads join sectors");
    
}

sub test_has_road_joining_to_only_one_joins : Tests(1) {
    my $self = shift;   
    
    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land($self->{schema});
    
    $self->{schema}->resultset('Road')->create(
        {
            position => 'bottom right',  
            land_id => $land[0]->id,
        },
    );

    # WHEN
    my $result = $land[0]->has_road_joining_to($land[4]);
    
    # THEN
    is($result, 0, "Roads don't join sectors");
    
}

1;
