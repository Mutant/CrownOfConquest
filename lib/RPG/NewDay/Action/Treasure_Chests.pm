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
	   },
	   {
	       prefetch => {'dungeon_grid' => {'dungeon_room' => 'dungeon'}},
	   },
	);
	
	foreach my $chest (@chests) {	    
		if ($chest->is_empty) {
		    if ($chest->dungeon_grid->dungeon_room->special_room_id && $chest->dungeon_grid->dungeon_room->special_room->room_type eq 'treasure') {
                # Add some more gold to some of the chests in the treasure room
                if (Games::Dice::Advanced->roll('1d100') <= 10) {
                    my $gold = (Games::Dice::Advanced->roll('1d200') + 250) * $chest->dungeon_grid->dungeon_room->dungeon->level;
                    $chest->gold($gold);
                    $chest->add_trap;
                    $chest->update;
                }
		    }
		    
			elsif (Games::Dice::Advanced->roll('1d100') <= $self->context->config->{empty_chest_fill_chance}) {
				$chest->fill(%item_types_by_prevalence);
			} 	
		}
	}
}

1;