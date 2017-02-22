use strict;
use warnings;

package Test::RPG::NewDay::Treasure_Chest;

use base qw(Test::RPG::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use Test::RPG::Builder::Treasure_Chest;
use Test::RPG::Builder::Item_Type;
use Test::RPG::Builder::Item;
use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Dungeon_Room;

use Test::More;
use Test::MockObject::Extends;

sub startup : Tests(startup => 1) {
    my $self = shift;

    use_ok('RPG::NewDay::Action::Treasure_Chests');

    $self->setup_context;
}

sub test_run : Tests(13) {
    my $self = shift;

    # GIVEN
    my @chests;
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );
    my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema},
        dungeon_id   => $dungeon->id,
        top_left     => { x => 1, y => 1 },
        bottom_right => { x => 5, y => 5 },
    );

    my @sectors = $room->sectors;

    for my $idx ( 1 .. 5 ) {
        my $chest = Test::RPG::Builder::Treasure_Chest->build_chest( $self->{schema}, dungeon_grid_id => $sectors[$idx]->id );

        push @chests, $chest;
    }

    my $item_type = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema}, prevalence => 100 );

    my $item1 = Test::RPG::Builder::Item->build_item( $self->{schema}, treasure_chest_id => $chests[2]->id, item_type_id => $item_type->id );
    my $item2 = Test::RPG::Builder::Item->build_item( $self->{schema}, treasure_chest_id => $chests[4]->id, item_type_id => $item_type->id );

    my $action = RPG::NewDay::Action::Treasure_Chests->new( context => $self->{mock_context} );

    $self->{config}{empty_chest_fill_chance} = 100;

    # WHEN
    $action->run;

    # THEN
    my $count = 0;
    foreach my $chest (@chests) {
        $chest->discard_changes;

        my @items = $chest->items;

        is( $chest->is_empty, 0, "Chest $count is not empty" );
        if ( $count == 2 || $count == 4 ) {
            is( scalar @items, 1, "Only 1 item in chest $count, as it wasn't empty" );
        }
        else {
            cmp_ok( scalar @items, '>=', 1, "1 or more items added to chest $count" );
            cmp_ok( scalar @items, '<=', 3, "3 or more items added to chest $count" );
        }

        $count++;
    }

}

1;
