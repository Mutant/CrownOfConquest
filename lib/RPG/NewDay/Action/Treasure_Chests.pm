package RPG::NewDay::Action::Treasure_Chests;

use Moose;

use Games::Dice::Advanced;

extends 'RPG::NewDay::Base';

sub cron_string {
    my $self = shift;
     
    return $self->context->config->{treasure_chest_cron_string};   
}

sub run {
	my $self = shift;
	
	my %item_types_by_prevalence = $self->context->schema->resultset('Item_Type')->get_by_prevalence;
	
	my @chests = $self->context->schema->resultset('Treasure_Chest')->search(
	   {
	       'dungeon.type' => {'!=', 'castle'},
	       'dungeon_room.special_room_id' => undef, # Treasure rooms shouldn't be re-filled
	   },
	   {
	       join => {'dungeon_grid' => {'dungeon_room' => 'dungeon'}},
	   },
	);
	
	foreach my $chest (@chests) {	    
		if ($chest->is_empty) {
			if (Games::Dice::Advanced->roll('1d100') <= $self->context->config->{empty_chest_fill_chance}) {
				$chest->fill(%item_types_by_prevalence);
			} 	
		}
	}
}

1;