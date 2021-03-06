package Test::RPG::ResultSet::CreatureGroup;

use strict;
use warnings;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::RPG::Builder::Land;
use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Dungeon_Room;
use Test::RPG::Builder::CreatureGroup;

use Test::More;
use Test::MockObject;

sub startup : Tests(startup) {
    my $self = shift;

    my $mock_maths = Test::MockObject::Extra->new();
    $mock_maths->fake_module(
        'RPG::Maths',
        weighted_random_number => sub {
            my $ret = $self->{weighted_random_number}[ $self->{counter} ];
            $self->{counter}++;
            return $ret;
        },
        roll_in_range => sub {
            my $ret = $self->{roll_in_range}[ $self->{roll_in_range_counter} ];
            $self->{roll_in_range_counter}++;
            return $ret;
        },
    );
    $self->{mock_maths} = $mock_maths;

}

sub setup : Tests(setup) {
    my $self = shift;

    $self->{counter}               = 0;
    $self->{roll_in_range_counter} = 0;

    $self->{cret_category} = $self->{schema}->resultset('Creature_Category')->create(
        {
            name => 'Test',
        },
    );
}

sub shutdown : Tests(shutdown) {
    my $self = shift;

    $self->{mock_maths}->unfake_module();
    $SIG{__WARN__} = sub {
        my ($msg) = @_;

        return if $msg =~ /Subroutine (\S+) redefined/;

        print STDERR $msg;
    };
    require RPG::Maths;
    $SIG{__WARN__} = undef;
}

sub test_create_in_wilderness_simple : Tests(5) {
    my $self = shift;

    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );

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

    $self->{weighted_random_number} = [3];
    $self->{roll_in_range} = [ 1, 2, 3 ];

    # WHEN
    my $cg = $self->{schema}->resultset('CreatureGroup')->create_in_wilderness(
        $land[0],
        1,
        1,
    );

    # THEN
    is( $cg->land_id, $land[0]->id, "CG created in correct land" );
    my @creatures = $cg->creatures;
    ok( scalar @creatures >= 3,  "At least 3 creatures" );
    ok( scalar @creatures <= 10, "No more than 10 creatures" );
    is( $creatures[0]->creature_type_id, $self->{creature_type_1}->id, "Creatures created of correct type" );
    $land[0]->discard_changes;
    is( $land[0]->creature_threat, 12, "Creature threat increased" );

}

sub test_create_in_wilderness_doesnt_use_same_type_twice : Tests(6) {
    my $self = shift;

    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );

    my $creature_type_1 = $self->{schema}->resultset('CreatureType')->create(
        {
            creature_type        => 'creature type',
            level                => 2,
            creature_category_id => $self->{cret_category}->id,
        }
    );

    my $creature_type_2 = $self->{schema}->resultset('CreatureType')->create(
        {
            creature_type        => 'creature type',
            level                => 2,
            creature_category_id => $self->{cret_category}->id,
        }
    );

    $self->{weighted_random_number} = [2];
    $self->{roll_in_range} = [ 2, 2 ];

    # WHEN
    my $cg = $self->{schema}->resultset('CreatureGroup')->create_in_wilderness(
        $land[0],
        1,
        1,
    );

    # THEN
    is( $cg->land_id, $land[0]->id, "CG created in correct land" );
    my @creatures = $cg->creatures;
    ok( scalar @creatures >= 3,  "At least 3 creatures" );
    ok( scalar @creatures <= 10, "No more than 10 creatures" );

    my %types = map { $_->creature_type_id => 1 } @creatures;
    is( $types{ $creature_type_1->id }, 1, "Type 1 used" );
    is( $types{ $creature_type_2->id }, 1, "Type 2 used" );

    $land[0]->discard_changes;
    is( $land[0]->creature_threat, 12, "Creature threat increased" );

}

sub test_find_in_dungeon_room_for_combat : Tests(2) {
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
            x => 5,
            y => 5,
        },
        create_walls => 1,
    );
    my ($dungeon_sector) = $room1->sectors;
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, dungeon_grid_id => $dungeon_sector->id );

    my ($find_from_sector) = grep { $_->x == 3 && $_->y == 3 } $room1->sectors;

    # WHEN
    my $found_cg = $self->{schema}->resultset('CreatureGroup')->find_in_dungeon_room_for_combat(
        sector       => $find_from_sector,
        search_range => 5,
    );

    # THEN
    is( $found_cg->id, $cg->id, "Found correct cg" );
}

1;
