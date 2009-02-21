package Test::RPG::ResultSet::Dungeon_Grid;

use strict;
use warnings;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Data::Dumper;

use Test::RPG::Builder::Dungeon_Grid;
use Test::RPG::Builder::Party;

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

sub test_get_party_grid_simple : Tests(5) {
    my $self = shift;

    # GIVEN
    my $dungeon = $self->{schema}->resultset('Dungeon')->create( {} );
    my $room = $self->{schema}->resultset('Dungeon_Room')->create( { dungeon_id => $dungeon->id, } );

    my $sector1 = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid(
        $self->{schema},
        x               => 1,
        y               => 1,
        walls           => [ 'top', 'right' ],
        doors           => ['top'],
        dungeon_room_id => $room->id,
    );

    my $sector2 = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid(
        $self->{schema},
        x               => 1,
        y               => 2,
        dungeon_room_id => $room->id,
    );

    my $party = Test::RPG::Builder::Party->build_party($self->{schema});

    $self->{schema}->resultset('Mapped_Dungeon_Grid')->create(
        {
            dungeon_grid_id => $sector1->id,
            party_id        => $party->id,
        }
    );

    # WHEN
    my @sectors = $self->{schema}->resultset('Dungeon_Grid')->get_party_grid($party->id, $dungeon->id,  );

    # THEN
    is( scalar @sectors, 1, "1 sector returned" );
    my $sector = shift @sectors;
    is ( $sector->{x}, 1, "Returned sector has correct x");
    is ( $sector->{y}, 1, "Returned sector has correct y");
    is_deeply( $sector->{walls}, ['top','right'], "Walls returned correctly");
    is_deeply( $sector->{doors}, ['top'], "Doors returned correctly");
}

1;
