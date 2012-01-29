use strict;
use warnings;

package Test::RPG::Schema::Quest::Find_Jewel;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Land;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::Shop;
use Test::RPG::Builder::Item_Type;
use Test::RPG::Builder::Item;
use Test::RPG::Builder::Quest::Find_Jewel;
use Test::RPG::Builder::Party;

use RPG::Schema::Quest::Find_Jewel;

sub setup : Tests(setup) {
	my $self = shift;
	
	my $quest = Test::MockObject->new();
	
	my $mock_resultsource = Test::MockObject->new();
	$mock_resultsource->set_always('schema', $self->{schema});
	
	$quest->set_always('result_source', $mock_resultsource);
	
	$self->{quest} = $quest;
}

sub test_find_jewel_type_to_use_basic : Tests(2) {
	my $self = shift;
	
	my $schema = $self->{schema};
	
	# GIVEN
	my $town = Test::RPG::Builder::Town->build_town($schema);
	my $jewel_type1 = Test::RPG::Builder::Item_Type->build_item_type($schema, category_name => 'Jewel', item_type => 'jewel1');
		
	$self->{quest}->set_always('town', $town);
	
	# WHEN
	my $jewel = RPG::Schema::Quest::Find_Jewel::_find_jewel_type_to_use($self->{quest});
	
	# THEN
	is(defined $jewel, 1, "Jewel to use returned");
	is($jewel->id, $jewel_type1->id, "Correct jewel type found");
		
}

sub test_find_jewel_type_to_use_jewels_exist_in_town : Tests(2) {
	my $self = shift;
	
	my $schema = $self->{schema};
	
	# GIVEN
	my $town = Test::RPG::Builder::Town->build_town($schema);
	my $shop = Test::RPG::Builder::Shop->build_shop($schema, town_id => $town->id);
	my $jewel_type1 = Test::RPG::Builder::Item_Type->build_item_type($schema, category_name => 'Jewel', item_type => 'jewel1');
	my $jewel_type2 = Test::RPG::Builder::Item_Type->build_item_type($schema, category_name => 'Jewel', item_type => 'jewel2');
	
	my $jewel = Test::RPG::Builder::Item->build_item($schema, item_type_id => $jewel_type1->id, shop_id => $shop->id);
		
	$self->{quest}->set_always('town', $town);
	
	# WHEN
	my $jewel_to_use = RPG::Schema::Quest::Find_Jewel::_find_jewel_type_to_use($self->{quest});
	
	# THEN
	is(defined $jewel_to_use, 1, "Jewel to use returned");
	is($jewel_to_use->id, $jewel_type2->id, "Correct jewel type found");		
}

sub test_find_jewel_type_to_use_all_jewel_types_exist_in_town : Tests(3) {
	my $self = shift;
	
	my $schema = $self->{schema};
	
	# GIVEN
	my $town = Test::RPG::Builder::Town->build_town($schema);
	my $shop = Test::RPG::Builder::Shop->build_shop($schema, town_id => $town->id);
	my $jewel_type1 = Test::RPG::Builder::Item_Type->build_item_type($schema, category_name => 'Jewel', item_type => 'jewel1');
	my $jewel_type2 = Test::RPG::Builder::Item_Type->build_item_type($schema, category_name => 'Jewel', item_type => 'jewel2');
	
	my $jewel1 = Test::RPG::Builder::Item->build_item($schema, item_type_id => $jewel_type1->id, shop_id => $shop->id);
	my $jewel2 = Test::RPG::Builder::Item->build_item($schema, item_type_id => $jewel_type2->id, shop_id => $shop->id);
		
	$self->{quest}->set_always('town', $town);
	
	# WHEN
	my $jewel_to_use = RPG::Schema::Quest::Find_Jewel::_find_jewel_type_to_use($self->{quest});
	
	# THEN
	is(defined $jewel_to_use, 1, "Jewel to use returned");
	
	# Figure out which jewel type was randomly deleted
	my $type_deleted;
	$type_deleted = $jewel_type1 if $jewel_to_use->id == $jewel_type1->id;
	$type_deleted = $jewel_type2 if $jewel_to_use->id == $jewel_type2->id;
	
	is(defined $type_deleted, 1, "One of the existing jewel types was deleted from the town");
	
	# Make sure all the jewels were deleted
	my @jewels_in_town = $schema->resultset('Items')->search(
		{
			'item_type.item_type_id' => $type_deleted->id,
			'in_town.town_id' => $town->id,
		},
		{
			join => [
				'item_type',
				{'in_shop' => 'in_town'},				
			], 
		},
	);	
	
	is(scalar @jewels_in_town, 0, "All jewels deleted out of the town's shop");		
}

sub test_create_jewels_in_range_basic : Tests(2) {
	my $self = shift;
	
	my $schema = $self->{schema};
	
	# GIVEN
	my @land = Test::RPG::Builder::Land->build_land($schema);
	my $origin_town = Test::RPG::Builder::Town->build_town($schema, land_id => $land[0]->id);
	my $target_town = Test::RPG::Builder::Town->build_town($schema, land_id => $land[8]->id);
	my $shop = Test::RPG::Builder::Shop->build_shop($schema, town_id => $target_town->id);
		
	my $jewel_type1 = Test::RPG::Builder::Item_Type->build_item_type($schema, category_name => 'Jewel', item_type => 'jewel1');
	
	$self->{quest}{_config}{search_range} = 3;
	$self->{quest}{_config}{jewels_to_create} = 1;
	
	# WHEN
	RPG::Schema::Quest::Find_Jewel::_create_jewels_in_range($self->{quest}, $origin_town, $origin_town->location, $jewel_type1);
	
	# THEN
	my @items_in_shop = $shop->items_in_shop;
	is(scalar @items_in_shop, 1, "One item in target town's shop");
	is($items_in_shop[0]->item_type_id, $jewel_type1->id, "Item of correct type");
			
}

sub test_create_jewels_in_range_jewel_quests_exist_in_target_town : Tests(1) {
	my $self = shift;
	
	my $schema = $self->{schema};
	
	# GIVEN
	my $quest = Test::RPG::Builder::Quest::Find_Jewel->build_quest($self->{schema});
	
	my @land = $schema->resultset('Land')->search();
	
	my $origin_town = Test::RPG::Builder::Town->build_town($schema, land_id => $land[8]->id);
	my $target_town = $quest->town;
	my $shop = Test::RPG::Builder::Shop->build_shop($schema, town_id => $target_town->id);
		
    my $jewel_type1 = $quest->jewel_type_to_find;
		
	$self->{quest}{_config}{search_range} = 3;
	$self->{quest}{_config}{jewels_to_create} = 1;
	
	# WHEN
	RPG::Schema::Quest::Find_Jewel::_create_jewels_in_range($self->{quest}, $origin_town, $origin_town->location, $jewel_type1);
	
	# THEN
	my @items_in_shop = $shop->items_in_shop;
	is(scalar @items_in_shop, 0, "No items created in shop, as town already has quests for this jewel type");			
}

sub test_check_action_success : Tests(2) {
	my $self = shift;
	
	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party($self->{schema});
	my $quest = Test::RPG::Builder::Quest::Find_Jewel->build_quest($self->{schema}, party_id => $party->id);
	$party->land_id($quest->town->land_id);
	$party->update;
	
	my $item = Test::RPG::Builder::Item->build_item($self->{schema}, item_type_id => $quest->jewel_type_to_find->id); 
	
	# WHEN
	my $result = $quest->check_action($party, 'sell_item', $item);
	
	# THEN
	is($result, 1, "Item sold in town, so quest completed");
	is($quest->param_current_value('Sold Jewel'), 1, "Jewel recorded as sold");
}

sub test_check_action_not_in_town : Tests(2) {
	my $self = shift;
	
	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party($self->{schema});
	my $quest = Test::RPG::Builder::Quest::Find_Jewel->build_quest($self->{schema}, party_id => $party->id);
	
	my $item = Test::RPG::Builder::Item->build_item($self->{schema}, item_type_id => $quest->jewel_type_to_find->id); 
	
	# WHEN
	my $result = $quest->check_action($party, 'sell_item', $item);
	
	# THEN
	is($result, 0, "Action not in town belong to this quest, so not successful");
	is($quest->param_current_value('Sold Jewel'), 0, "Jewel not recorded as sold");
}

1;