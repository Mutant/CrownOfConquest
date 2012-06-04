package RPG::Schema::Election;
use base 'DBIx::Class';
use strict;
use warnings;

use Games::Dice::Advanced;
use Math::Round qw(round);

use RPG::Schema::Day;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Election');

__PACKAGE__->resultset_class('RPG::ResultSet::Election');

__PACKAGE__->add_columns(qw/election_id town_id scheduled_day status/);

__PACKAGE__->set_primary_key('election_id');

__PACKAGE__->belongs_to(
    'town',
    'RPG::Schema::Town',
    'town_id',
);

__PACKAGE__->has_many(
    'candidates',
    'RPG::Schema::Election_Candidate',
    'election_id',
);

sub days_until_election {
    my $self = shift;
    
    my $today = $self->result_source->schema->resultset('Day')->find_today();
    
    return RPG::Schema::Day::_diff_str($self->scheduled_day - $today->day_number);
}

sub cancel {
    my $self = shift;
    
	$self->status("Cancelled");
	$self->update;
	
	# Give back any campaign spends
	my @candidates = $self->search_related(
	   'candidates',
	   {
	       campaign_spend => {'>=', 0},
	   }
    );
    
    my $today = $self->result_source->schema->resultset('Day')->find_today;
    
    foreach my $candidate (@candidates) {
        my $character = $candidate->character;
        if (! $character->is_npc) {
            my $party = $character->party;
            $party->increase_gold($candidate->campaign_spend);
            $party->update;
            
            $party->add_to_messages(
                {
                    alert_party => 1,
                    day_id => $today->id,
                    message => 'The election in ' . $self->town->town_name . ' has been cancelled. Your campaign spend of ' . 
                        $candidate->campaign_spend . ' gold has been returned to the party',
                }
            );         
        }   
    }
}

sub get_scores {
    my $self = shift;
    
    my @candidates = $self->candidates;
	my $town = $self->town;
	my $mayor = $town->mayor;
	
	my %scores;

	foreach my $candidate (@candidates) {    
		my $campaign_spend = $candidate->campaign_spend / 20;
		my $rating_bonus = 0;

		my $character = $candidate->character;
		
		if ($character->id == $mayor->id) {
			$rating_bonus = $town->mayor_rating;
			
			my $building = $town->building;
			if ($building) {
                $rating_bonus += $building->building_type->level * 20;
			}
		}
		elsif (! $character->is_npc) {			
			my $party_town = $character->party->find_related(
                'party_towns',
				{
					town_id => $town->id,
				}
			);
			
			# Bit of a penalty so mayors are harder to oust
			$rating_bonus = $party_town->prestige - 20 if $party_town;
			$rating_bonus = 0 if $rating_bonus < 0;
		}
		else {
			# NPC's get a bump based on the town's prosperity
			my $prosp = $town->prosperity;
			
			if ($prosp > 25) {
				$rating_bonus = round ($prosp / 10);
			}
		}
		
		my $charisma_adjustment = $character->execute_skill('Charisma', 'election') // 0;
		
		my $random = Games::Dice::Advanced->roll('1d20') - 10;
		
		my $score = $campaign_spend + $rating_bonus + $charisma_adjustment + $random;
		
		# If character is in the morgue, they get a score of 0.
		#  This can happen if they were at the inn, couldn't pay, then went to the street and got killed.
		$score = 0 if $character->status && $character->status eq 'morgue';
		
		$scores{$character->id} = {
		    character => $character,
            spend => $campaign_spend,
            rating => $rating_bonus,
            charisma => $charisma_adjustment,
            random => $random,
            total => $score,
		};
	}
	
	return %scores;
}

1;