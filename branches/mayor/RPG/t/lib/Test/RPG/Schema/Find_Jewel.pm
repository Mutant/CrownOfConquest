use strict;
use warnings;

package Test::RPG::Schema::Find_Jewel;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

sub startup : Tests(startup=>1) {
	use_ok('RPG::Schema::Quest::Find_Jewel');
}

sub setup_data : Tests(setup) {
	my $self = shift;
	
	$self->{quest_type} = $self->{schema}->resultset('Quest_Type')->create(
		{
			quest_type => 'find_jewel',	
		}
	);
	
	$self->{quest_param_name_1} = $self->{schema}->resultset('Quest_Param_Name')->create(
		{
			quest_param_name => 'Jewel To Find',
			quest_type_id => $self->{quest_type}->id,
		}
	);

	$self->{quest_param_name_2} = $self->{schema}->resultset('Quest_Param_Name')->create(
		{
			quest_param_name => 'Sold Jewel',
			quest_type_id => $self->{quest_type}->id,
		}
	);
	
	my $item_cat = $self->{schema}->resultset('Item_Category')->create(
		{
			item_category => 'Jewel',
		}
	);
	
	$self->{jewel_type} = $self->{schema}->resultset('Item_Type')->create(
		{
			item_type => 'Jewel Type 1',
			item_category_id => $item_cat->id,
		}
	);
	
	my $location1 = $self->{schema}->resultset('Land')->create(
		{
			x => 1,
			y => 1,
		}
	);
	
	$self->{town} = $self->{schema}->resultset('Town')->create(
		{
			land_id => $location1->id,
		},
	);

	my $shop = $self->{schema}->resultset('Shop')->create(
		{
			town_id => $self->{town}->id, 
		}
	);
	
	$self->{jewel_in_town} = $self->{schema}->resultset('Items')->create(
		{
			item_type_id => $self->{jewel_type}->id,
			shop_id => $shop->id,
		}
	);
	
	my $location2 = $self->{schema}->resultset('Land')->create(
		{
			x => 5,
			y => 5,
		}
	);
	
	$self->{town_2} = $self->{schema}->resultset('Town')->create(
		{
			land_id => $location2->id,
		},
	);

	my $shop2 = $self->{schema}->resultset('Shop')->create(
		{
			town_id => $self->{town_2}->id, 
		}
	);
	
	$self->{config} = {
		quest_type_vars => {
			find_jewel => {
				search_range => 3,
				jewels_to_create => 3,
				gold_value => 100,
				xp_value => 100,
			},			
		},
	};	
	
}

sub delete_data : Tests(teardown) {
	my $self = shift;
	
	$self->{schema}->storage->dbh->rollback;
}

sub test_create_find_jewel_quest : Tests(4) {
	my $self = shift;
	
	my $quest = $self->{schema}->resultset('Quest')->create(
		{
			quest_type_id => $self->{quest_type}->id,
			town_id => $self->{town}->id,
		},
	);
	
	isa_ok($quest, 'RPG::Schema::Quest::Find_Jewel', "Quest created in right package");
	
	my $jewel = $self->{schema}->resultset('Items')->find($self->{jewel_in_town}->id);
	
	is($jewel, undef, "Jewel in town was deleted to allow quest to be created"); 
	is($quest->param_start_value('Jewel To Find'), $self->{jewel_type}->id, "Correct jewel set as Jewel To Find");
	
	my $jewel_rs = $self->{schema}->resultset('Items')->search(
		{
			'item_type.item_type_id' => $self->{jewel_type}->id,
			'in_town.town_id' => $self->{town_2}->id,
		},
		{
			join => [
				'item_type',
				{'in_shop' => 'in_town'},				
			], 
		},
	);
	
	is($jewel_rs->count, 3, "Three jewels created in second town");
	
}