package RPG::NewDay::Action::Election;
use Moose;

extends 'RPG::NewDay::Base';

use Games::Dice::Advanced;
use Math::Round qw(round);
use List::Util qw(shuffle);

sub run {
    my $self = shift;
    
    my $c = $self->context;
    
    my @elections = $c->schema->resultset('Election')->search(
    	{
    		status => 'Open',
    	}
    );
    
    $c->logger->debug(scalar @elections . " open elections");
    
    foreach my $election (@elections) {
    	if ($election->scheduled_day == $c->current_day->day_number) {
    		$self->run_election($election);
    		next;	
    	}    	
    	
    	my $npc_candidates = grep { $_->character->is_npc } $election->candidates;
    	my $expected_npcs = round ($election->town->prosperity / 20);
    	$expected_npcs = 2 if $expected_npcs < 2;
    	
    	$c->logger->debug("Election for town " . $election->town_id . " has $npc_candidates npc candidates, needs $expected_npcs");
    	
    	if ($npc_candidates < $expected_npcs) {
    		my $npcs_to_create = Games::Dice::Advanced->roll('1d3');
    		$npcs_to_create = $expected_npcs if $npcs_to_create > $expected_npcs;
    		
    		$c->logger->debug("Generating $npcs_to_create npc candidates");
    		
    		for (1..$npcs_to_create) {
    			my $level = round $election->town->prosperity / 4;
    			$level = 8  if $level < 8;
				$level = 20 if $level > 20;
				
				my $character = $c->schema->resultset('Character')->generate_character(
					allocate_equipment => 1,
					level              => $level,
				);
				
				$c->schema->resultset('Election_Candidate')->create(
					{
						character_id => $character->id,
						election_id => $election->id,
					},
				);
				
				$c->schema->resultset('Town_History')->create(
	                {
	                    town_id => $election->town_id,
	                    day_id  => $c->current_day->id,
	                    message => $character->name . " announces " . $character->pronoun('posessive-subjective') . " candidacy for the upcoming election",
	                }
	            );				
    		}
    	}
    }
}

sub run_election {
	my $self = shift;
	my $election = shift;
	
	my $c = $self->context;
	
	my $town = $election->town;
	my $mayor = $town->mayor;
	
	my @candidates = $election->candidates;
	my $highest_score;
	my $winner;
	
	$c->logger->debug("Running election for town: " . $town->id);
	
	my %scores = $election->get_scores();
	
    $election->status('Closed');
	$election->update;
	
	foreach my $char_id (keys %scores) {
	    my $char_score = $scores{$char_id};
	
		$c->logger->debug("Character $char_id scores: " . $char_score->{total} . " [spend: " . $char_score->{spend} . 
		  ", rating: " . $char_score->{rating} . ", charisma: " . $char_score->{charisma} . ", random: " . $char_score->{random} . "]"); 
		
		if (! defined $highest_score || $highest_score < $char_score->{total}) {
			$winner	= $char_score->{character};
			$highest_score = $char_score->{total};
		}
	}
	
	if ($winner->id == $mayor->id) {
		$c->logger->debug("Mayor retains office");
		$town->increase_mayor_rating(10);
		$town->update;	
		
		$c->schema->resultset('Town_History')->create(
        	{
				town_id => $election->town_id,
				day_id  => $c->current_day->id,
                message => $mayor->character_name . " wins the election, retaining office",
			}
		);		
	}
	else {
		$c->logger->debug("Mayor loses to character: " . $winner->id);
		
		$mayor->lose_mayoralty(0);
				
		$winner->mayor_of($town->id);
		$winner->update;
		
		$winner->apply_roles;
		
		$winner->gain_mayoralty($town);
						
		$c->schema->resultset('Town_History')->create(
        	{
				town_id => $election->town_id,
				day_id  => $c->current_day->id,
                message => $winner->character_name . " wins the election, ousting the incumbant, " . $mayor->character_name,
			}
		);
	}
	
	# Alert the party of any player characters of the result
	foreach my $candidate (@candidates) {
		my $character = $candidate->character;
		
		# Skip npcs
		next if $character->is_npc;
		
		my $message;
		if ($character->id != $winner->id) {
		    # Character was a loser
		    $message = $character->character_name . " lost the recent election in " . $town->town_name . ' to ' . $winner->character_name . '.';
		    
		    if ($character->id == $mayor->id) {
                $message .= ucfirst $character->pronoun('subjective') . ' is no longer mayor.'; 
		    }
		}
		else {
		    # Character was the winner
            $message = $character->character_name . " won the recent election in " . $town->town_name;
            
            if ($character->id == $mayor->id) {
                $message .= ' and is still mayor.';    
            }
            else {
                $message .= ' and is now mayor!';
            }
		}
		
        $character->party->add_to_messages(
            {
                message => $message,
                alert_party => 1,
                day_id => $c->current_day->id,
            }
        ); 
	}

	$town->last_election($election->scheduled_day);
	$town->update;	
}

__PACKAGE__->meta->make_immutable;