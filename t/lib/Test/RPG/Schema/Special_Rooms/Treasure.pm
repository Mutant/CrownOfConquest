package Test::RPG::Schema::Special_Rooms::Treasure;

use strict;
use warnings;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Dungeon_Room;
use Test::RPG::Builder::Item_Type;

sub test_make_sepecial : Tests(20) {
    my $self = shift;
    
    # GIVEN  
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema}, level => 2);
  
    my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, 
        dungeon_id => $dungeon->id,
        special_room_type => 'treasure',
        top_left => {x=>1, y=>1},
        bottom_right => {x=>5,y=>5},
    );
    
    $self->mock_dice;
    $self->{rolls} = [1, 100, 110, 120, 130, 140, 3, 1, 1, 1];    
    
    my $special_room_type = $self->{schema}->resultset('Dungeon_Special_Room')->find(
        {
            room_type => 'treasure',
        }
    );
    
    my $item_type1 = Test::RPG::Builder::Item_Type->build_item_type($self->{schema}, enchantments => [ 'indestructible' ]);
    my $item_type2 = Test::RPG::Builder::Item_Type->build_item_type($self->{schema}, enchantments => [ 'featherweight' ]);
    my $item_type3 = Test::RPG::Builder::Item_Type->build_item_type($self->{schema});
    
    # WHEN
    $room->make_special($special_room_type);
    
    # THEN
    is(defined $room->special_room_id, 1, "Special room id set");
    
    my @chests = $self->{schema}->resultset('Treasure_Chest')->search();
    
    is(scalar @chests, 5, "5 chests generated");
    
    my @items;
    foreach my $chest (@chests) {
        cmp_ok($chest->items->count, '<=', 1, "Chest has 1 or less items");
        push @items, $chest->items;
        cmp_ok($chest->gold, '>=', 700, "Chest gold above correct range");
        cmp_ok($chest->gold, '<=', 780, "Chest gold below correct range");
    }
    
    is(scalar @items, 2, "Correct number of items generated");
    cmp_ok($items[0]->enchantments_count, '>=', 1, "At least one enchantment on first item");
    cmp_ok($items[1]->enchantments_count, '>=', 1, "At least one enchantment on second item");
    
    
    $self->unmock_dice;
    
}

sub test_remove_special : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema}, level => 2);
  
    my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, 
        dungeon_id => $dungeon->id,
        special_room_type => 'treasure',
        top_left => {x=>1, y=>1},
        bottom_right => {x=>5,y=>5},
    );
    $room->generate_special;
    
    # WHEN
    $room->remove_special;
    
    # THEN
    my @chests = $self->{schema}->resultset('Treasure_Chest')->search();
    is(scalar @chests, 0, "All chests removed");
}

1;
