package Test::RPG::Schema::Dungeon_Room;

use strict;
use warnings;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

sub startup : Test(startup => 1) {
    my $self = shift;

    $self->{mock_rpg_schema} = Test::MockObject->new();
    $self->{mock_rpg_schema}->fake_module( 'RPG::Schema', 'config' => sub { $self->{config} }, );

    use_ok 'RPG::Schema::Dungeon_Room';
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

sub test_connected_to_room : Tests(2) {
    my $self = shift;

    # GIVEN
    my $dungeon = $self->{schema}->resultset('Dungeon')->create( {} );
    
    my $room1 = $self->{schema}->resultset('Dungeon_Room')->create( 
        {
            dungeon_id => $dungeon->id,
        } 
    );

    for my $x ( 1 .. 2 ) {
        for my $y ( 1 .. 2 ) {
            my $sector = $self->{schema}->resultset('Dungeon_Grid')->create(
                {
                    x               => $x,
                    y               => $y,
                    dungeon_room_id => $room1->id,
                }
            );

            if ( $x == 2 && $y == 1 ) {
                my $door = $self->{schema}->resultset('Door')->create(
                    {
                        dungeon_grid_id => $sector->id,
                        position_id     => $self->{positions}{right},
                    }
                );
            }
        }
    }

    my $room2 = $self->{schema}->resultset('Dungeon_Room')->create( 
        {
            dungeon_id => $dungeon->id,
        } 
    );

    my $sector = $self->{schema}->resultset('Dungeon_Grid')->create(
        {
            x               => 3,
            y               => 1,
            dungeon_room_id => $room2->id,
        }
    );

    # WHEN
    my $rooms_connected = $room1->connected_to_room( $room2->id );

    # THEN
    is( $rooms_connected, 1, "Rooms are connected" );
    
    is( $rooms_connected, 1, "Rooms are connected (second time uses cache)" );

}

1;
