use strict;
use warnings;

package Test::RPG::Schema::Treasure_Chest;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Dungeon_Room;
use Test::RPG::Builder::Treasure_Chest;
use Test::RPG::Builder::Item_Type;
use Test::RPG::Builder::Quest::Find_Dungeon_Item;
use Test::RPG::Builder::Quest::Find_Jewel;

sub startup : Tests(startup) {
    my $self = shift;
    
    my $mock_maths = Test::MockObject::Extra->new();
    $mock_maths->fake_module(
        'RPG::Maths',
        weighted_random_number => sub {
            my $ret = $self->{weighted_random_number}[$self->{counter}];
            $self->{counter}++;
            return $ret;
        },
        roll_in_range => sub {
            my $ret = $self->{roll_in_range}[$self->{roll_in_range_counter}];
            $self->{roll_in_range_counter}++;
            return $ret;
        },        
    );
    $self->{mock_maths} = $mock_maths;
    
    $self->mock_dice;
}

sub shutdown : Tests(shutdown) {
    my $self = shift;
    
    $self->{mock_maths}->unfake_module();
    require RPG::Maths;
    
    $self->unmock_dice;
}

sub test_fill : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema}, level => 2);
    my $dungeon_room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, 
        dungeon_id => $dungeon->id,
        top_left => {
            x => 1,
            y => 1,
        },
        bottom_right => {
            x => 3,
            y => 3,
        }
    );
    my @sectors = $dungeon_room->sectors;
    
    my $chest = Test::RPG::Builder::Treasure_Chest->build_chest($self->{schema}, dungeon_grid_id => $sectors[0]->id);
    
    $self->{weighted_random_number} = [1,1];
    
    my $it1 = Test::RPG::Builder::Item_Type->build_item_type($self->{schema}, prevalence => 50);
    my $it2 = Test::RPG::Builder::Item_Type->build_item_type($self->{schema}, prevalence => 40);
    
    my %item_types_by_prevalence = (
        40 => [$it2],
        50 => [$it1],
    );        
    
    $self->{roll_result} = 1;
    
    # WHEN
    $chest->fill(%item_types_by_prevalence);
    
    # THEN
    my @items = $chest->items;
    is(scalar @items, 1, "1 item added to the chest");
    is($items[0]->item_type->item_type_id, $it1->id, "Item type is correct");
    
}

sub test_delete_removed_related_quests : Tests(3) {
    my $self = shift;
    
    # GIVEN    
    my $quest = Test::RPG::Builder::Quest::Find_Dungeon_Item->build_quest($self->{schema});
	my $quest2 = Test::RPG::Builder::Quest::Find_Jewel->build_quest($self->{schema});
	my $quest3 = Test::RPG::Builder::Quest::Find_Dungeon_Item->build_quest($self->{schema});
	my $dungeon = $quest->dungeon;
	my $item = $quest->item;
	
	my $chest = $self->{schema}->resultset('Treasure_Chest')->find( $item->treasure_chest_id ); 
	
	# WHEN
	$chest->delete;
	
	# THEN
	$quest->discard_changes;
	is($quest->in_storage, 0, "Quest deleted when chest deleted");
		
	$quest2->discard_changes;
	is($quest2->in_storage, 1, "Non-dungeon quest not deleted");	
	
	$quest3->discard_changes;
	is($quest3->in_storage, 1, "Quest relating to different chest not deleted");	
}
1;
