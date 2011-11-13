package RPG::Schema::Quest::Find_Dungeon_Item;

use base 'RPG::Schema::Quest';

use strict;
use warnings;

use List::Util qw(shuffle);
use RPG::Map;
use RPG::Exception;

sub set_quest_params {
    my $self = shift;
    
    my $town = $self->town;
    my $town_location = $town->location;
        
    my $search_range = $self->{_config}{search_range};
    
	my ($start_point, $end_point) = RPG::Map->surrounds(
    	$town_location->x,
    	$town_location->y,
    	$search_range,
    	$search_range,
    );
    
    # Find dungeons to place the item
    my $dungeon_rs = $self->result_source->schema->resultset('Dungeon')->search(
    	{
   		    'location.x' => {'>=', $start_point->{x}, '<=', $end_point->{x}},
			'location.y' => {'>=', $start_point->{y}, '<=', $end_point->{y}},
			'type' => 'dungeon',
    	},
    	{
    		join => 'location',
    	},
    );
    
    # No dungeons in range, throw exception
    if ($dungeon_rs->count == 0) {
    	$self->delete;
        die RPG::Exception->new(
            message => "Can't find dungeon in range of town, skipping quest creation",
            type    => 'quest_creation_error',
        );    	
    }
    
    my @dungeons = $dungeon_rs->all;
    my $dungeon_to_use = (shuffle @dungeons)[0];
    
    # Find chest to add item to
    my @chests = $self->result_source->schema->resultset('Treasure_Chest')->search(
    	{
    		'dungeon.dungeon_id' => $dungeon_to_use->id,
    		'dungeon_room.special_room_id' => undef,
    	},
    	{
    		join => { 'dungeon_grid' => { 'dungeon_room' => 'dungeon' }},
    	}    	
    );
    
    unless (@chests) {
		# TODO: try another dungeon?
		$self->delete;
        die RPG::Exception->new(
            message => "Can't find chest in the dungeon, skipping",
            type    => 'quest_creation_error',
        );   	
    }
    
    my $chest = (shuffle @chests)[0];
    
    my $item_type = $self->result_source->schema->resultset('Item_Type')->find(
    	{
    		item_type => 'Artifact',
    	}
   	);
   	
    my $file = RPG::Schema->config->{data_file_path} . 'quest_items.txt';
    open( my $names_fh, '<', $file ) || die "Couldn't open names file: $file ($!)\n";
    my @item_names = <$names_fh>;
    close($names_fh);
    chomp @item_names;
    
    my $item_name = (shuffle @item_names)[0];
    
    my $item = $self->result_source->schema->resultset('Items')->create(
    	{
    		item_type_id => $item_type->id,
    		name => $item_name,
    		treasure_chest_id => $chest->id,
    	}
    );
    
    $self->define_quest_param('Item', $item->id);
    
    $self->define_quest_param('Dungeon', $dungeon_to_use->id);
    
    $self->define_quest_param('Item Found', 0);
    
    my $distance = RPG::Map->get_distance_between_points(
        {
            x => $town_location->x,
            y => $town_location->y,
        },
        {
            x => $dungeon_to_use->location->x,
            y => $dungeon_to_use->location->y,
        },
    );    
    
    $self->gold_value($self->{_config}{gold_per_distance} * $distance * $dungeon_to_use->level);
    $self->xp_value( $self->{_config}{xp_per_distance} * $distance * $dungeon_to_use->level );
    $self->min_level( ($dungeon_to_use->level - 1) * RPG::Schema->config->{dungeon_entrance_level_step}  );
    
    my $days_to_complete = int $distance / 2;
    $days_to_complete = 20 if $days_to_complete < 20;
    $self->days_to_complete($days_to_complete);
	
	$self->update;
}

sub check_action {
    my $self   = shift;
    my $party  = shift;
    my $action = shift;
    my $dungeon_id = shift;
    my $items_found = shift;

    return 0 unless $action eq 'chest_opened';

    return 0 unless $dungeon_id == $self->param_start_value('Dungeon');
    
    return 0 unless grep { $_->id == $self->param_start_value('Item') } @$items_found;

    my $quest_param = $self->param_record('Item Found');
    $quest_param->current_value(1);
    $quest_param->update;

    return 1;
}

sub item {
	my $self = shift;
	
	return $self->result_source->schema->resultset('Items')->find( $self->param_start_value('Item') );	
}

sub dungeon {
	my $self = shift;
	
	return $self->result_source->schema->resultset('Dungeon')->find( $self->param_start_value('Dungeon') );	
}

sub ready_to_complete {
    my $self = shift;

    return 0 unless $self->param_current_value('Item Found');
    
    # Check the item is in a character's inventory, and that character is in the party
    #  (i.e. not in a garrison, etc)
    my $item = $self->result_source->schema->resultset('Items')->find(
    	{
    		'party.party_id' => $self->party_id,
    		'item_id' => $self->param_start_value('Item'), 
    	},
    	{
    		join => {'belongs_to_character' => 'party'},
    	}
    );

    return 0 unless $item;
    
    return 0 unless $item->belongs_to_character->is_in_party;
    
    return 1;
}

sub finish_quest {
	my $self = shift;
	
	my $item = $self->item;
	return unless $item;
	$item->character_id(undef);
	$item->treasure_chest_id(undef);
	$item->land_id(undef);
	$item->update;
}

sub cleanup {
	my $self = shift;
		
	# Any in progress quests send a message to party
	if ($self->status eq 'In Progress' && ! $self->param_current_value('Item Found')) {
        my $today = $self->result_source->schema->resultset('Day')->find_today;
		
        $self->result_source->schema->resultset('Party_Messages')->create(
            {
                party_id => $self->party->id,
                message  => "The town of " . $self->town->town_name
                    . " sends you a message that the local town watch has managed to retrieve the "
                    . $self->item->name . " from the dungeon themselves. Your quest has therefore been terminated amicably.",
                alert_party => 1,
                day_id      => $today->id,
            }
        );		
	}
	
	$self->finish_quest;
}

1;