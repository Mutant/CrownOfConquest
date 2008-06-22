use strict;
use warnings;

package RPG::NewDay::Party;

use Math::Round qw(round);

sub run {
	my $package = shift;
	my ($config, $schema) = @_;
	
	my $party_rs = $schema->resultset('Party')->search( {}, { prefetch => 'characters' });
	
	while (my $party = $party_rs->next) {
		$party->turns($party->turns + $config->{daily_turns});
		$party->turns($config->{maximum_turns}) if $party->turns > $config->{maximum_turns};

		my $percentage_to_heal = $config->{min_heal_percentage} + $party->rest * $config->{max_heal_percentage} / 10;

		foreach my $character ($party->characters) {
			# Heal chars based on amount of rest they've had during the day
			if ($party->rest != 0) {				
				my $hp_increase = round $character->max_hit_points * $percentage_to_heal / 100;
				$hp_increase = 1 if $hp_increase == 0; # Always a min of 1
				
				$character->change_hit_points($hp_increase);
			}
				
			# Memorise new spells for the day
			my @spells_to_memorise = $schema->resultset('Memorised_Spells')->search(
		    	{ 
			        character_id => $character->id,
			    },			  
			);
			
			foreach my $spell (@spells_to_memorise) {
				if ($spell->memorise_tomorrow) {
					$spell->memorised_today(1);
					$spell->memorise_count($spell->memorise_count_tomorrow);
					$spell->number_cast_today(0);
					$spell->update;
				}
				else {
					# Spell no longer memorised, so delete the record
					$spell->delete;	
				}	
			}
				
			$character->update;
		}
		
		# They're no rested
		$party->rest(0);
		$party->update;
	}
}

1;