package RPG::Schema::Quest::Find_Jewel;

use base 'RPG::Schema::Quest';

use strict;
use warnings;

use List::Util qw(shuffle);
use RPG::Map;

sub set_quest_params {
    my $self = shift;
    
    my $jewel_type_to_use = $self->_find_jewel_type_to_use;
    
    my $town = $self->town;
    my $town_location = $town->location;
        
    my $search_range = $self->{_config}{search_range};    
    
	my ($start_point, $end_point) = RPG::Map->surrounds(
    	$town_location->x,
    	$town_location->y,
    	$search_range,
    	$search_range,
    );
    
    # Make sure there are jewels nearby
    my $jewel_rs = $self->result_source->schema->resultset('Items')->search(
    	{
   		    'location.x' => {'>=', $start_point->{x}, '<=', $end_point->{x}},
			'location.y' => {'>=', $start_point->{y}, '<=', $end_point->{y}},
			'in_town.town_id' => {'!=', $town->id},
			'item_type_id' => $jewel_type_to_use->id,
    	},
    	{
    		join => {'in_shop' => {'in_town' => 'location'}},
    	},
    );
    
    # No jewels in range, so create some
    if ($jewel_rs->count == 0) {
    	$self->_create_jewels_in_range($town, $town_location, $jewel_type_to_use);
    }
    
    $self->define_quest_param('Jewel To Find', $jewel_type_to_use->id);
    $self->define_quest_param('Sold Jewel', 0);
    
    $self->gold_value($self->{_config}{gold_value});
	$self->xp_value($self->{_config}{xp_value});
	$self->update;
}
 
sub _find_jewel_type_to_use {
	my $self = shift;
	
 	# Find which jewel to use. We find a jewel type that isn't in a shop in town.
 	#  We do this in two queries, or we'd need to do an outer join which is a hassle
	my @jewels = $self->result_source->schema->resultset('Item_Type')->search(
		{
			'category.item_category' => 'Jewel',
		},
		{
			join => 'category',
		},
	);
	
	my @jewels_in_town = $self->result_source->schema->resultset('Item_Type')->search(
		{
			'category.item_category' => 'Jewel',
			'in_town.town_id' => $self->town->id,
		},
		{
			join => [
				'category',
				{
					'items' => {'in_shop' => 'in_town'},
				},
			],
		},
	);
	
	my @jewels_to_pick_from = @jewels;
	
	foreach my $jewel_in_town (@jewels_in_town) {
		@jewels_to_pick_from = grep { $_->id != $jewel_in_town->id } @jewels_to_pick_from;	
	}
	
	my $jewel_to_use;	
	
	unless (@jewels_to_pick_from) {
		# Hmm, seems every jewel type is in town. Pick one at ramdom and delete all of the items of that type in town.
		@jewels = shuffle @jewels;
		
		$jewel_to_use = shift @jewels;
		
		my @jewels_for_deletion = $self->result_source->schema->resultset('Items')->search(
			{
				'item_type.item_type_id' => $jewel_to_use->id,
				'in_town.town_id' => $self->town->id,
			},
			{
				join => [
					'item_type',
					{'in_shop' => 'in_town'},				
				], 
			},
		);
		map { $_->delete } @jewels_for_deletion;
	}
	else {
		@jewels_to_pick_from = shuffle @jewels_to_pick_from;
		$jewel_to_use = shift @jewels_to_pick_from;
	}
	
	return $jewel_to_use;		   
}

sub _create_jewels_in_range {
	my $self = shift;
	my $town = shift;
	my $town_location = shift;
	my $jewel_type_to_use = shift;

    my @towns_in_range = $self->result_source->schema->resultset('Town')->find_in_range(
    	{
    		x => $town_location->x,
    		y => $town_location->y,
    	},
   		$self->{_config}{search_range},
   		2,
   	);
    	
   	my $town_to_create_in;
   	TOWN_LOOP: foreach my $town_to_check (@towns_in_range) {
   		# Check town doesn't have quests in progress for this jewel type
   		my @quests = $self->result_source->schema->resultset('Quest')->search(
   			{
   				town_id => $town_to_check->id,
   				complete => 0,
   			},
   			{
   				prefetch => [
   					'quest_params',
   					'type',
   				],
   			},
   		);
    		    		
   		foreach my $quest (@quests) {
   			if ($quest->isa(__PACKAGE__) && $quest->param_start_value('Jewel To Find') == $jewel_type_to_use->id) {
   				# Can't use this town
   				next TOWN_LOOP;
   			}
   		}
    		
   		# This town is ok
   		$town_to_create_in = $town_to_check;
   		last;
   	}
    	
   	unless ($town_to_create_in) {
   		# TODO: Throw exception?
   	}
   	else {
   		my @shops = $town_to_create_in->shops;
   		for (1..$self->{_config}{jewels_to_create}) {
   			@shops = shuffle @shops;
   			$self->result_source->schema->resultset('Items')->create(
   				{
   					item_type_id => $jewel_type_to_use->id,
   					shop_id => $shops[0]->id,
   				}
   			);
   		}
   	}	
}

sub check_action {
	my $self = shift;
	my $party = shift;
	my $action = shift;
	my $item = shift;
	
	return 0 unless $action eq 'sell_item';
	
	return 0 if $self->param_current_value('Sold Jewel') == 1;
	
	if ($item->item_type->id == $self->param_current_value('Jewel To Find')) {
		my $quest_param = $self->param_record('Sold Jewel');
		$quest_param->current_value(1);
		$quest_param->update;
		
		return 1;		
	}
	
	return 0;
}

sub ready_to_complete {
	my $self = shift;
	
	return $self->param_current_value('Sold Jewel');
}

sub jewel_type_to_find {
	my $self = shift;
	
	return $self->result_source->schema->resultset('Item_Type')->find($self->param_start_value('Jewel To Find'));
}

1;