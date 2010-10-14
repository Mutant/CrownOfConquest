package RPG::NewDay::Action::Election;
use Moose;

extends 'RPG::NewDay::Base';

use Games::Dice::Advanced;
use Math::Round qw(round);

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

__PACKAGE__->meta->make_immutable;