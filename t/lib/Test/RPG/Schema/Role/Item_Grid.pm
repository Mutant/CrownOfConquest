use strict;
use warnings;

package Test::RPG::Schema::Item_Grid;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Try::Tiny;
use Data::Dumper;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Item;

sub test_add_item_to_grid : Tests(4) {
    my $self = shift;

    # GIVEN
    my $char = Test::RPG::Builder::Character->build_character( $self->{schema} );
    $char->create_item_grid;

    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id        => $char->id,
        width          => 2,
        height         => 2,
        no_equip_place => 1,
    );

    # WHEN
    $char->add_item_to_grid($item);

    # THEN
    my @grid = $char->search_related( 'item_sectors', { item_id => $item->id } );
    is( scalar @grid,           4, "Item added to 4 sectors" );
    is( $grid[0]->x,            1, "First item sector is x=1" );
    is( $grid[0]->y,            1, "First item sector is y=1" );
    is( $grid[0]->start_sector, 1, "First item sector is start sector" );
}

sub test_add_item_to_grid_when_full : Tests(1) {
    my $self = shift;

    # GIVEN
    my $char = Test::RPG::Builder::Character->build_character( $self->{schema} );
    $char->create_item_grid;

    my $item1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id        => $char->id,
        width          => 7,
        height         => 7,
        no_equip_place => 1,
    );
    $char->add_item_to_grid($item1);

    my $item2 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id        => $char->id,
        width          => 2,
        height         => 2,
        no_equip_place => 1,
    );

    try {
        # WHEN
        $char->add_item_to_grid($item2);
    }
    catch {
        # THEN
        like( $_, qr{^Couldn't find room for item}, "Second item couldn't be added to grid because there's no room" );
    };
}

sub test_deleting_item_in_grid_doesnt_delete_grid : Tests(1) {
    my $self = shift;

    # GIVEN
    my $char = Test::RPG::Builder::Character->build_character( $self->{schema} );
    $char->create_item_grid;

    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id        => $char->id,
        width          => 2,
        height         => 2,
        no_equip_place => 1,
    );

    $char->add_item_to_grid($item);

    # WHEN
    $item->delete;

    # THEN
    is( $char->item_sectors->count, 64, "Character still has correct number of grid sectors" );
}

1;
