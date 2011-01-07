package RPG::Schema::Role::Character::Mayor;

# Methods for characters who are mayors

use Moose::Role;

sub lose_mayoralty {
	my $self = shift;
	
	confess "Not a mayor" unless $self->mayor_of;

	my $town = $self->mayor_of_town;
	
	$self->mayor_of(undef);
	$self->creature_group_id(undef);
	
	unless ($self->is_npc) {
   		$self->status('morgue');
		$self->status_context($town->id);
		$self->hit_points(0);
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
   		$char->status('morgue');
		$char->status_context($town->id);
		$char->hit_points(0);
		$char->update;
	}
	
   	$town->mayor_rating(0);
   	$town->peasant_state(undef);
   	$town->last_election(undef);
   	$town->update;    	    	    		
		
}

1;