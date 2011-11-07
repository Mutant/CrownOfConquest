use strict;
use warnings;

package Test::RPG::C::Dungeon;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use RPG::C::Dungeon;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Item;
use Test::RPG::Builder::Quest::Find_Dungeon_Item;
use Test::RPG::Builder::Dungeon_Grid;
use Test::RPG::Builder::Dungeon_Room;
use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Treasure_Chest;
use Test::RPG::Builder::Day;

use Data::Dumper;
use List::Util qw(shuffle);

sub test_hide_item_from_party_with_no_name : Tests(1) {
	my $self = shift;
	
	my $schema = $self->{schema};
	
	# GIVEN
	my $item = Test::RPG::Builder::Item->build_item($schema);
	
	# WHEN
	my $result = RPG::C::Dungeon->hide_item_from_party($self->{c}, $item);
	
	# THEN
	is($result, 0, "Item has no name, so cannot be a quest item");
}

sub test_hide_item_from_party_with_no_quest : Tests(1) {
	my $self = shift;
	
	my $schema = $self->{schema};
	
	# GIVEN
	my $item = Test::RPG::Builder::Item->build_item($schema, name => 'foo');
	
	# WHEN
	my $result = RPG::C::Dungeon->hide_item_from_party($self->{c}, $item);
	
	# THEN
	is($result, 0, "Item has no related quest, so cannot be a quest item");
}

sub test_hide_item_from_party_with_quest : Tests(1) {
	my $self = shift;
	
	my $schema = $self->{schema};
	
	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party($schema);
	$self->{stash}{party} = $party;
	
	# Needed to create a quest
    $self->{config}{quest_type_vars}{find_dungeon_item}{search_range} = 3;
    $self->{config}{quest_type_vars}{find_dungeon_item}{gold_per_distance} = 45;
    $self->{config}{quest_type_vars}{find_dungeon_item}{xp_per_distance} = 30;
    $self->{config}{data_file_path} = 'data/';
    $self->{config}{dungeon_entrance_level_step} = 5; 
    
    my $quest = Test::RPG::Builder::Quest::Find_Dungeon_Item->build_quest($schema, party_id => $party->id);
    
    my $item = $quest->item;
	
	# WHEN
	my $result = RPG::C::Dungeon->hide_item_from_party($self->{c}, $item);
	
	# THEN
	is($result, 0, "Item has related quest, and quest is owned by this party, therefore don't hide item");
}

sub test_hide_item_from_party_with_quest_by_other_party : Tests(1) {
	my $self = shift;
	
	my $schema = $self->{schema};
	
	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party($schema);
	$self->{stash}{party} = $party;
	
	# Needed to create a quest
    $self->{config}{quest_type_vars}{find_dungeon_item}{search_range} = 3;
    $self->{config}{quest_type_vars}{find_dungeon_item}{gold_per_distance} = 45;
    $self->{config}{quest_type_vars}{find_dungeon_item}{xp_per_distance} = 30;
    $self->{config}{data_file_path} = 'data/';
    $self->{config}{dungeon_entrance_level_step} = 5; 
    
    my $quest = Test::RPG::Builder::Quest::Find_Dungeon_Item->build_quest($schema, party_id => $party->id+1);
    
    my $item = $quest->item;
	
	# WHEN
	my $result = RPG::C::Dungeon->hide_item_from_party($self->{c}, $item);
	
	# THEN
	is($result, 1, "Item has related quest, but quest is owned by another party, therefore hide item");
}

sub test_hide_item_from_party_with_quest_not_started : Tests(1) {
	my $self = shift;
	
	my $schema = $self->{schema};
	
	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party($schema);
	$self->{stash}{party} = $party;
	    
    my $quest = Test::RPG::Builder::Quest::Find_Dungeon_Item->build_quest($schema);
    
    my $item = $quest->item;
	
	# WHEN
	my $result = RPG::C::Dungeon->hide_item_from_party($self->{c}, $item);
	
	# THEN
	is($result, 1, "Item has related quest, but quest is not owned by a party, therefore hide item");
}

sub test_open_chest_with_quest_item : Tests(2) {
	my $self = shift;
	
	my $schema = $self->{schema};
	
	# GIVEN
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon($schema);
        
    my $dungeon_room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room(
    	$schema, 
    	dungeon_id => $dungeon->id,
    	top_left => { x=> 1, y=> 1 },
    	bottom_right => { x=> 5, y => 5 },
    );
    
    my $sector = (shuffle $dungeon_room->sectors)[0];	
	
	my $chest = Test::RPG::Builder::Treasure_Chest->build_chest($self->{schema}, dungeon_grid_id => $sector->id);
	
	my $item1 = Test::RPG::Builder::Item->build_item($self->{schema}, treasure_chest_id => $chest->id);
	my $item2 = Test::RPG::Builder::Item->build_item($self->{schema}, treasure_chest_id => $chest->id);
	
	my $quest = Test::RPG::Builder::Quest::Find_Dungeon_Item->build_quest($schema);
	my $item3 = $quest->item;
	
	my $party = Test::RPG::Builder::Party->build_party($self->{schema}, dungeon_grid_id => $sector->id, character_count => 2);
	$self->{stash}{party} = $party;
	
	my $day = Test::RPG::Builder::Day->build_day($self->{schema});
	
	$self->{mock_forward}{'/quest/check_action'} = sub { [] };
	$self->{mock_forward}{'/panel/refresh'} = sub {};
	
	# WHEN
	RPG::C::Dungeon->open_chest($self->{c});
	
	# THEN
	my $template_params = $self->template_params;
	my @items_found = @{ $template_params->{items_found} };
	is(scalar @items_found, 2, "only 2 items found, as other is invisible because it's a quest item");
	
	my @expected = sort ($item1->id, $item2->id);
	my @got = sort ($items_found[0]->{item}->id, $items_found[1]->{item}->id);
	
	is_deeply(\@got, \@expected, "Correct items found");  
}

sub test_handle_chest_trap_not_triggered : Tests(1) {
	my $self = shift;
	
	# GIVEN
	$self->mock_dice;
	
	my $dungeon_grid = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid($self->{schema});
	my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 2, dungeon_grid_id => $dungeon_grid->id);
	
	$self->{stash}{party} = $party;
	
	$self->{roll_result} = 9;
	
	my $triggered = 0;
	$self->{mock_forward}{trigger_trap} = sub { $triggered = 1 }; 
	
	$self->{mock_forward}{'/panel/refresh'} = sub {};
	
	# WHEN
	RPG::C::Dungeon->handle_chest_trap($self->{c}, $dungeon_grid);
	
	# THEN
	is($triggered, 0, "Trap not triggered");
	
	$self->unmock_dice;
	
}

sub test_handle_chest_trap_triggered : Tests(1) {
	my $self = shift;
	
	# GIVEN
	$self->mock_dice;
	
	my $dungeon_grid = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid($self->{schema});
	my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 2, dungeon_grid_id => $dungeon_grid->id);
	
	$self->{stash}{party} = $party;
	
	$self->{roll_result} = 11;
	
	my $triggered = 0;
	$self->{mock_forward}{trigger_trap} = sub { $triggered = 1 }; 
	
	$self->{mock_forward}{'/panel/refresh'} = sub {};
	
	# WHEN
	RPG::C::Dungeon->handle_chest_trap($self->{c}, $dungeon_grid);
	
	# THEN
	is($triggered, 1, "Trap triggered");
	
	$self->unmock_dice;
	
}

sub test_handle_chest_trap_with_skill_bonus : Tests(1) {
	my $self = shift;
	
	# GIVEN
	$self->mock_dice;
	
	my $dungeon_grid = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid($self->{schema});
	my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 2, dungeon_grid_id => $dungeon_grid->id);
	my @chars = $party->characters;
	
    my $skill = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Awareness',
        }
    );
    
    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id => $skill->id,
            character_id => $chars[0]->id,
            level => 5,
        }
    );	
	
	$self->{stash}{party} = $party;
	
	$self->{roll_result} = 18;
	
	my $triggered = 0;
	$self->{mock_forward}{trigger_trap} = sub { $triggered = 1 }; 
	
	$self->{mock_forward}{'/panel/refresh'} = sub {};
	
	# WHEN
	RPG::C::Dungeon->handle_chest_trap($self->{c}, $dungeon_grid);
	
	# THEN
	is($triggered, 0, "Trap not triggered");
	
	$self->unmock_dice;
	
	
}

1;