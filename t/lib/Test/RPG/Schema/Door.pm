package Test::RPG::Schema::Door;

use strict;
use warnings;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Dungeon_Grid;

sub dungeon_setup : Tests(setup) {
    my $self = shift;

    # Query Dungeon_Positions
    my %positions = map { $_->position => $_->id} $self->{schema}->resultset('Dungeon_Position')->search();

    $self->{positions} = \%positions;
}

sub test_opposite_door : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $dungeon = $self->{schema}->resultset('Dungeon')->create(
        {},
    );

    my $dungeon_room = $self->{schema}->resultset('Dungeon_Room')->create(
        {
            dungeon_id => $dungeon->id,
        },
    );
    
    my $sector1 = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid($self->{schema},
        x => 1,
        y => 1,
        walls => ['bottom'],
        doors => ['bottom'],
        dungeon_room_id => $dungeon_room->id,
    );

    my $sector2 = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid($self->{schema},
        x => 1,
        y => 2,
        walls => ['top'],
        doors => ['top'],
        dungeon_room_id => $dungeon_room->id,
    );
    
    my ($door1) = $sector1->doors;
    my ($door2) = $sector2->doors; 
    
    # WHEN
    my $opp_door = $door1->opposite_door;
    
    # THEN
    isa_ok($opp_door, 'RPG::Schema::Door', "Door object returned");
    is($opp_door->id, $door2->id, "Correct door returned");

}

1;