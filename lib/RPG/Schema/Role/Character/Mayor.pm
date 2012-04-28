package RPG::Schema::Role::Character::Mayor;

# Methods for characters who are mayors

use Moose::Role;

sub lose_mayoralty {
	my $self = shift;
	my $killed = shift // 1;
	my $switch_mayor = shift // 0;
	
	confess "Not a mayor" unless $self->mayor_of;

	my $town = $self->mayor_of_town;
    my $today = $self->result_source->schema->resultset('Day')->find_today;
	
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
	
	$self->add_to_history(
        {
            event => $self->character_name . " is no longer the mayor of " . $town->town_name,
            day_id => $today->id,
        }
	);
    
    # Cancel election, if there's one in progress
    my $election = $town->current_election;
    if ($election) {
        $election->cancel;
    }	
	
	my @garrison_chars = $self->result_source->schema->resultset('Character')->search(
		{
			status => 'mayor_garrison',
			status_context => $town->id,
			party_id => $self->party_id,
		}
	);
	
	foreach my $char (@garrison_chars) {
	    if (! $switch_mayor) {
    		if ($killed) {			
    	   		$char->status('morgue');
    			$char->status_context($town->id);
    			$char->hit_points(0);
    		}
    		else {
    			$char->status('inn');
    			$char->status_context($town->id);			
    		}
	    }
		$char->creature_group_id(undef);
		$char->update;
	}
	
	if (! $switch_mayor) {
       	$town->mayor_rating(0);
       	$town->peasant_state(undef);
       	$town->last_election(undef);
       	$town->tax_modified_today(0);
       	$town->update;
	}
   	
   	if (! $self->is_npc) { 	    
    	my $history_rec = $self->result_source->schema->resultset('Party_Mayor_History')->find(
            {
                party_id => $self->party_id,
                town_id => $town->id,
                lost_mayoralty_day => undef,
            }
        );
        
        if ($history_rec) {                  
            $history_rec->lost_mayoralty_day($today->id);
            $history_rec->update;
        }
   	}	
}

sub gain_mayoralty {
    my $self = shift;
    my $town = shift;
        
    $self->status(undef);
    $self->status_context(undef);
    $self->update;
        
    my $cg = $self->create_creature_group();

	my $schema = $self->result_source->schema;

	my $today = $self->result_source->schema->resultset('Day')->find_today;
	
	if (! $self->is_npc) {        
        my $party = $self->party;
        
       	# If they have negative prestige, reset it to 0
    	my $party_town = $schema->resultset('Party_Town')->find_or_create(
    		{
    			party_id => $party->id,
    			town_id  => $town->id,
    		},
    	);
    	if ($party_town->prestige < 0) {
    		$party_town->prestige(0);
    		$party_town->update;	
    	}
	    
    	$schema->resultset('Party_Mayor_History')->create(
    	   {
    	       mayor_name => $self->character_name,
    	       character_id => $self->id,
    	       town_id => $town->id,
    	       got_mayoralty_day => $today->id,
    	       party_id => $party->id,
    	       creature_group_id => $cg->id,
    	   }
    	);
	}
	
	$self->add_to_history(
	   {
	       day_id => $today->id,
	       event => $self->character_name . ' is now the mayor of ' . $town->town_name,
	   }
	);
}

# Called when the mayor was defeated in battle, and they should be removed from office
sub was_killed {
    my $self = shift;
    my $killing_party = shift;
    
    my $town = $self->mayor_of_town;
    
    $self->lose_mayoralty;
        
    my $today = $self->result_source->schema->resultset('Day')->find_today;
		
	# Leave a message for the mayor's party
	if ($self->party_id) {
	    my $party = $self->party;
		$party->add_to_messages(
			{
				message => $self->character_name . " was killed by the party " . $killing_party->name . " and is no longer mayor of " 
				. $town->town_name . ". " . ucfirst $self->pronoun('posessive-subjective') . " body has been interred in the town cemetery, and "
				. $self->pronoun('posessive') . " may be resurrected there.",
				alert_party => 1,
				party_id => $self->party_id,
				day_id => $today->id,
			}
		);
	}
	
	my $town_history_msg = "Mayor " . $self->character_name . " was dishonoured in combat by " . $killing_party->name . ". " . 
	   ucfirst $self->pronoun('subjective') . " has been thrown out of office in disgrace.";
           		
    if ($town->peasant_state eq 'revolt') {
    	$town_history_msg .= " The peasants give up their revolt."; 
    }
           		
	$town->add_to_history(
   		{
			day_id  => $today->id,
           	message => $town_history_msg,
   		}
   	);           
}

around 'defence_factor' => sub {
    my $orig = shift;
    my $self = shift;
    
    my $df = $self->$orig(@_);
    
    my $town = $self->mayor_of_town;
    
    $df += int $town->prosperity / 20;
    
    return $df;      
};

sub create_creature_group {
    my $self = shift;
    
    my $schema = $self->result_source->schema;
    
    my $cg = $schema->resultset('CreatureGroup')->create(
		{
			creature_group_id => undef,
		}
	);       
	
	$self->creature_group_id($cg->id);
	$self->update;
	
	# Add any garrisoned chars into the group
	my @garrison_chars = $schema->resultset('Character')->search(
		{
			status => 'mayor_garrison',
			status_context => $self->mayor_of,
			party_id => $self->party_id,
		}
	);
	
	foreach my $character (@garrison_chars) {
		$character->creature_group_id($cg->id);
		$character->update;
	}
	
	return $cg;
}

1;