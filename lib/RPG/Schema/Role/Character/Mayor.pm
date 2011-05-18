package RPG::Schema::Role::Character::Mayor;

# Methods for characters who are mayors

use Moose::Role;

sub lose_mayoralty {
	my $self = shift;
	my $killed = shift // 1;
	
	confess "Not a mayor" unless $self->mayor_of;

	my $town = $self->mayor_of_town;
	
	$self->mayor_of(undef);
	$self->creature_group_id(undef);
	
	unless ($self->is_npc) {
		if ($killed) {
	   		$self->status('morgue');
			$self->status_context($town->id);
			$self->hit_points(0);
		}
		else {
			$self->status('inn');
			$self->status_context($town->id);
		}
	}		
	
	$self->update;
	
	my @garrison_chars = $self->result_source->schema->resultset('Character')->search(
		{
			status => 'mayor_garrison',
			status_context => $town->id,
			party_id => $self->party_id,
		}
	);
	
	foreach my $char (@garrison_chars) {
		if ($killed) {			
	   		$char->status('morgue');
			$char->status_context($town->id);
			$char->hit_points(0);
		}
		else {
			$char->status('inn');
			$char->status_context($town->id);			
		}
		$char->creature_group_id(undef);
		$char->update;
	}
	
   	$town->mayor_rating(0);
   	$town->peasant_state(undef);
   	$town->last_election(undef);
   	$town->tax_modified_today(0);
   	$town->update;    	    	    		
		
}

1;