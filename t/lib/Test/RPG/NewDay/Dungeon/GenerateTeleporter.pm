use strict;
use warnings;

package Test::RPG::NewDay::Dungeon::GenerateTeleporter;

use base qw(Test::RPG::Base::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use Test::More;
use Test::MockObject::Extends;

use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Dungeon_Room;

sub startup : Tests(startup => 1) {
    my $self = shift;

    use_ok('RPG::NewDay::Action::Dungeon');

    $self->setup_context;
}

sub teardown : Tests(teardown) {
    my $self = shift;

    $self->unmock_dice;
}

sub test_generate_teleporter_basic : Tests(3) {
    my $self = shift;

    # GIVEN
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );
    my $room1 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema},
        dungeon_id   => $dungeon->id,
        top_left     => { x => 1, y => 1 },
        bottom_right => { x => 3, y => 3 },
    );
    my $room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema},
        dungeon_id   => $dungeon->id,
        top_left     => { x => 3, y => 1 },
        bottom_right => { x => 6, y => 3 },
    );

    $self->mock_dice;
    $self->{rolls} = [ 1, 30, 40, 30 ];

    my $action = RPG::NewDay::Action::Dungeon->new( context => $self->{mock_context} );

    # WHEN
    $action->generate_teleporters($dungeon);

    # THEN
    my @teleporters = $self->{schema}->resultset('Dungeon_Teleporter')->search(
        {
            'dungeon_room.dungeon_id' => $dungeon->id,
        },
        {
            join => { 'dungeon_grid' => 'dungeon_room' },
        }
    );

    is( scalar @teleporters,        1, "1 teleporter generated" );
    is( $teleporters[0]->invisible, 0, "Teleporter not invisible" );
    isnt( $teleporters[0]->dungeon_grid->dungeon_room_id, $teleporters[0]->destination->dungeon_room_id, "Two ends of teleporter in different rooms" );
}

sub test_generate_teleporter_two_way : Tests(7) {
    my $self = shift;

    # GIVEN
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );
    my $room1 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema},
        dungeon_id   => $dungeon->id,
        top_left     => { x => 1, y => 1 },
        bottom_right => { x => 3, y => 3 },
    );
    my $room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema},
        dungeon_id   => $dungeon->id,
        top_left     => { x => 3, y => 1 },
        bottom_right => { x => 6, y => 3 },
    );

    $self->mock_dice;
    $self->{rolls} = [ 1, 30, 40, 25 ];

    my $action = RPG::NewDay::Action::Dungeon->new( context => $self->{mock_context} );

    # WHEN
    $action->generate_teleporters($dungeon);

    # THEN
    my @teleporters = $self->{schema}->resultset('Dungeon_Teleporter')->search(
        {
            'dungeon_room.dungeon_id' => $dungeon->id,
        },
        {
            join => { 'dungeon_grid' => 'dungeon_room' },
        }
    );

    is( scalar @teleporters, 2, "2 teleporters generated" );

    is( $teleporters[0]->invisible, 0, "First teleporter not invisible" );
    isnt( $teleporters[0]->dungeon_grid->dungeon_room_id, $teleporters[0]->destination->dungeon_room_id, "Two ends of first teleporter in different rooms" );

    is( $teleporters[1]->invisible, 0, "Second teleporter not invisible" );
    isnt( $teleporters[1]->dungeon_grid->dungeon_room_id, $teleporters[1]->destination->dungeon_room_id, "Two ends of second teleporter in different rooms" );

    is( $teleporters[1]->dungeon_grid_id, $teleporters[0]->destination_id, "First teleporter has second teleporter as destination" );
    is( $teleporters[0]->dungeon_grid_id, $teleporters[1]->destination_id, "Second teleporter has first teleporter as destination" );
}

sub test_generate_teleporter_deletion : Tests(3) {
    my $self = shift;

    # GIVEN
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );
    my $room1 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema},
        dungeon_id   => $dungeon->id,
        top_left     => { x => 1, y => 1 },
        bottom_right => { x => 3, y => 3 },
    );
    my $room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema},
        dungeon_id   => $dungeon->id,
        top_left     => { x => 3, y => 1 },
        bottom_right => { x => 6, y => 3 },
    );

    my @room1_sectors = $room1->sectors;
    my @room2_sectors = $room2->sectors;
    my $teleporter = $self->{schema}->resultset('Dungeon_Teleporter')->create(
        {
            dungeon_grid_id => $room1_sectors[0]->id,
            destination_id  => $room2_sectors[0]->id,
            invisible       => 0,
        }
    );

    $self->mock_dice;
    $self->{rolls} = [ 1, 30, 40, 30 ];

    my $action = RPG::NewDay::Action::Dungeon->new( context => $self->{mock_context} );

    # WHEN
    $action->generate_teleporters($dungeon);

    # THEN
    my @teleporters = $self->{schema}->resultset('Dungeon_Teleporter')->search(
        {
            'dungeon_room.dungeon_id' => $dungeon->id,
        },
        {
            join => { 'dungeon_grid' => 'dungeon_room' },
        }
    );

    is( scalar @teleporters, 1, "1 teleporter generated" );
    isnt( $teleporters[0]->id, $teleporter->id, "New teleporter created" );
    $teleporter->discard_changes;
    is( $teleporter->in_storage, 0, "Old teleporter deleted" );
}

1;
