use strict;
use warnings;

package Test::RPG::NewDay::Castles;

use base qw(Test::RPG::Base::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use Data::Dumper;

use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::Treasure_Chest;
use Test::RPG::Builder::Dungeon_Room;

use RPG::NewDay::Action::Castles;

use Test::More;

sub setup : Test(setup) {
    my $self = shift;

    $self->setup_context;
}

sub test_fill_chests : Tests(1) {
    my $self = shift;

    # GIVEN
    $self->mock_dice;
    $self->{roll_result} = 100;

    my $castle = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $castle->land_id, prosperity => 50 );
    my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, top_left => { x => 1, y => 1 }, bottom_right => { x => 5, y => 5 }, dungeon_id => $castle->id );
    my @sectors = $room->sectors;

    my $chest1 = Test::RPG::Builder::Treasure_Chest->build_chest( $self->{schema}, dungeon_grid_id => $sectors[0]->id );
    my $chest2 = Test::RPG::Builder::Treasure_Chest->build_chest( $self->{schema}, dungeon_grid_id => $sectors[1]->id );
    my $chest3 = Test::RPG::Builder::Treasure_Chest->build_chest( $self->{schema}, dungeon_grid_id => $sectors[2]->id );

    # WHEN
    RPG::NewDay::Action::Castles->fill_chests( $castle, $chest1, $chest2, $chest3 );

    # THEN
    my $gold = 0;
    foreach my $chest ( $chest1, $chest2, $chest3 ) {
        $chest->discard_changes;
        $gold += $chest->gold;
    }
    is( $gold, 1350, "Correct amount of gold added to chests" );

    $self->unmock_dice;
}

sub test_generate_chests : Tests(5) {
    my $self = shift;

    # GIVEN
    my $castle = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );
    my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, top_left => { x => 1, y => 1 }, bottom_right => { x => 5, y => 5 }, dungeon_id => $castle->id );
    my $room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, top_left => { x => 6, y => 6 }, bottom_right => { x => 10, y => 10 }, dungeon_id => $castle->id );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $castle->land_id, gold => 520, prosperity => 10 );
    my $sector = ( $room->sectors )[0];
    $sector->stairs_up(1);
    $sector->update;

    $self->mock_dice;
    $self->{roll_result} = 1;

    my @sectors = $room->sectors;

    my $chest1 = Test::RPG::Builder::Treasure_Chest->build_chest( $self->{schema}, dungeon_grid_id => $sectors[0]->id );
    my $chest2 = Test::RPG::Builder::Treasure_Chest->build_chest( $self->{schema}, dungeon_grid_id => $sectors[1]->id );

    my $action = RPG::NewDay::Action::Castles->new( context => $self->{mock_context} );

    # WHEN
    $action->generate_chests($castle);

    # THEN
    $chest1->discard_changes;
    $chest2->discard_changes;
    is( $chest1->in_storage, 0, "First chest deleted" );
    is( $chest2->in_storage, 0, "Second chest deleted" );

    my @chests = $self->{schema}->resultset('Treasure_Chest')->search(
        {
            'dungeon_room.dungeon_id' => $castle->id,
        },
        {
            join => { 'dungeon_grid' => 'dungeon_room' },
        }
    );
    foreach my $chest (@chests) {
        is( $chest->dungeon_grid->dungeon_room_id, $room2->id, "Chest in room 2" );
    }

    $self->unmock_dice;

}

1;
