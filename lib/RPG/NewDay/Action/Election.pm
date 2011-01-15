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
	
	# We shuffle the candidates, in case there is a tie
	#  The first one we find with that score will win
	foreach my $candidate (shuffle @candidates) {
		my $campaign_spend = $candidate->campaign_spend / 20;
		my $rating_bonus = 0;

		my $character = $candidate->character;
		
		if ($character->id == $mayor->id) {
			$rating_bonus = $town->mayor_rating;
		}
		elsif (! $character->is_npc) {			
			my $party_town = $c->schema->resultset('Party_Town')->find(
				{
					town_id => $town->id,
					party_id => $character->party->id,
				}
			);
			
			# Bit of a penalty so mayors are harder to oust
			$rating_bonus = $party_town->prestige - 20;
			$rating_bonus = 0 if $rating_bonus < 0;
		}
		else {
			# NPC's get a bump based on the town's prosperity
			my $prosp = $town->prosperity;
			
			if ($prosp > 25) {
				$rating_bonus = round ($prosp / 10);
			}
		}
		
		my $random = Games::Dice::Advanced->roll('1d20') - 10;
		
		my $score = $campaign_spend + $rating_bonus + $random;
		
		# If character is in the morgue, they get a score of 0.
		#  This can happen if they were at the inn, couldn't pay, then went to the street and got killed.
		$score = 0 if $character->status eq 'morgue';
		
		$c->logger->debug("Character " . $character->id . " scores: $score [spend: $campaign_spend, rating: $rating_bonus, random: $random]"); 
		
		if (! defined $highest_score || $highest_score < $score) {
			$winner	= $character;
			$highest_score = $score;
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
				
		unless ($mayor->is_npc) {					
			$c->schema->resultset('Party_Messages')->create(
				{
					message => $mayor->character_name . " lost the recent election in " . $town->town_name . ' to ' . $winner->character_name . '. '
						. ucfirst $mayor->pronoun('subjective') . " is now at the town inn.",
					alert_party => 1,
					party_id => $mayor->party_id,
					day_id => $c->current_day->id,
				}
			);
		}
		
		$winner->mayor_of($town->id);
		$winner->update;
				
		$c->schema->resultset('Town_History')->create(
        	{
				town_id => $election->town_id,
				day_id  => $c->current_day->id,
                message => $winner->character_name . " wins the election, ousting the incumbant, " . $mayor->character_name,
			}
		);
	}
	
	# Alert any player characters if they lost
	foreach my $candidate (@candidates) {
		my $character = $candidate->character;
		
		# Skip npcs, the winner, and the previous mayor
		next if $character->is_npc || $character->id == $winner->id || $character->id == $mayor->id;
		
		$c->schema->resultset('Party_Messages')->create(
			{
				message => $character->character_name . " lost the recent election in " . $town->town_name . ' to ' . $winner->character_name . '.',
				alert_party => 1,
				party_id => $character->party_id,
				day_id => $c->current_day->id,
			}
		);		
	}

	$election->status('Closed');
	$election->update;

	$town->last_election($election->scheduled_day);
	$town->update;	
}

__PACKAGE__->meta->make_immutable;