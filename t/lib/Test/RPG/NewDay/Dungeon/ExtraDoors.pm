use strict;
use warnings;

package Test::RPG::NewDay::Dungeon::ExtraDoors;

use base qw(Test::RPG::Base::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use Test::More;
use Data::Dumper;

use Test::RPG::Builder::Dungeon_Room;

sub startup : Tests(startup => 1) {
    my $self = shift;

    use_ok('RPG::NewDay::Action::Dungeon');

    $self->setup_context;
}

sub test_generate_extra_doors : Tests(10) {
    my $self = shift;

    # GIVEN
    my $room1 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room(
        $self->{schema},
        create_walls => 1,
        top_left     => {
            x => 1,
            y => 1,
        },
        bottom_right => {
            x => 3,
            y => 3,
        },
    );

    my $room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room(
        $self->{schema},
        create_walls => 1,
        top_left     => {
            x => 4,
            y => 1,
        },
        bottom_right => {
            x => 6,
            y => 3,
        },
    );

    my @sectors = ( $room1->sectors, $room2->sectors );

    my $action = RPG::NewDay::Action::Dungeon->new( context => $self->{mock_context} );

    # WHEN
    $action->_generate_extra_doors( \@sectors );

    # THEN
    my @sectors_with_doors;
    foreach my $sector ( $room1->sectors ) {
        my @doors = $sector->sides_with_doors;
        push @sectors_with_doors, $sector if @doors;
    }

    is( scalar @sectors_with_doors, 1, "1 sector in room 1 now has a door" );

    is( $sectors_with_doors[0]->x, 3, "Door created in correct x position" );
    cmp_ok( $sectors_with_doors[0]->y, '>=', 1, "Door created above correct y range" );
    cmp_ok( $sectors_with_doors[0]->y, '<=', 3, "Door created below correct y range" );

    my @doors = $sectors_with_doors[0]->doors;
    is( scalar @doors,                 1,       "1 door record created" );
    is( $doors[0]->position->position, 'right', "Correct door position" );

    my $opposite_door = $doors[0]->opposite_door;
    is( $opposite_door->position->position, 'left', "Opposite door in correct position" );

    my $opposite_sector = $opposite_door->dungeon_grid;

    is( $opposite_sector->x, 4, "Door created in correct opposite x position" );
    cmp_ok( $opposite_sector->y, '>=', 1, "Door created above correct opposite y range" );
    cmp_ok( $opposite_sector->y, '<=', 3, "Door created below correct opposite y range" );
}

sub test_generate_extra_doors_existing_door : Tests(2) {
    my $self = shift;

    # GIVEN
    my $room1 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room(
        $self->{schema},
        create_walls => 1,
        top_left     => {
            x => 1,
            y => 1,
        },
        bottom_right => {
            x => 3,
            y => 3,
        },
    );

    my $room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room(
        $self->{schema},
        create_walls => 1,
        top_left     => {
            x => 4,
            y => 1,
        },
        bottom_right => {
            x => 6,
            y => 3,
        },
    );

    my @sectors = ( $room1->sectors, $room2->sectors );

    my ($left_sector)  = grep { $_->x == 3 && $_->y == 1 } @sectors;
    my ($right_sector) = grep { $_->x == 4 && $_->y == 1 } @sectors;

    my %positions = map { $_->position => $_->position_id } $self->{schema}->resultset('Dungeon_Position')->search();

    my $door1 = $self->{schema}->resultset('Door')->create(
        {
            position_id     => $positions{'right'},
            dungeon_grid_id => $left_sector->id,
            type            => 'standard',
        }
    );

    my $door2 = $self->{schema}->resultset('Door')->create(
        {
            position_id     => $positions{'left'},
            dungeon_grid_id => $right_sector->id,
            type            => 'standard',
        }
    );

    my $action = RPG::NewDay::Action::Dungeon->new( context => $self->{mock_context} );

    # WHEN
    $action->_generate_extra_doors( \@sectors );

    # THEN
    my @sectors_with_doors;
    foreach my $sector ( $room1->sectors ) {
        my @doors = $sector->sides_with_doors;
        push @sectors_with_doors, $sector if @doors;
    }

    is( scalar @sectors_with_doors, 1, "1 sector with door in room (existing door)" );
    my @doors = $sectors_with_doors[0]->doors;
    is( $doors[0]->id, $door1->id, "Door is existing door (nothing generated)" );
}

1;
