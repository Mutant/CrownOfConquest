package RPG::Combat::MagicalDamage::Fire;

use strict;
use warnings;

use Games::Dice::Advanced;
use RPG::Maths;
use List::Util qw(shuffle);
use RPG::Combat::ActionResult;
use RPG::Combat::MagicalDamageResult;

sub apply {
	my $self   = shift;
	my %params = @_;

	my $magical_damage_result = RPG::Combat::MagicalDamageResult->new(
		type => 'Fire',
	);

	my $roll         = 2 * $params{level};
	my $extra_damage = Games::Dice::Advanced->roll( '1d' . $roll ) + 2;

	my $resisted = $params{opponent}->hit_with_resistance('Fire', $extra_damage, $params{character});
	
	if ($resisted) {
        $magical_damage_result->resisted(1);
		return $magical_damage_result;
	}

	$magical_damage_result->extra_damage($extra_damage);

	my $number_of_others = RPG::Maths->weighted_random_number(0..2);
	
	if ($number_of_others) {
		my @group = shuffle grep { ! $_->is_dead && $_->id != $params{opponent}->id } $params{opponent_group}->members;
		
		$number_of_others = scalar @group if scalar @group < $number_of_others;
		
		my $other_roll = int $roll / 2;
		
		my @others_results;
		for (1..$number_of_others) {
			my $other = shift @group;
			
			my $other_damage_result = RPG::Combat::MagicalDamageResult->new(
				type => 'Fire',
				effect => 'seared',
			);
			
			my $other_damage = Games::Dice::Advanced->roll( '1d' . $other_roll );
			
			if ( $other->hit_with_resistance( 'Fire', $other_damage, $params{character} ) ) {
				$other_damage_result->resisted(1);	
			}
			else {
				$other_damage_result->extra_damage($other_damage);				
				$other->update;
			}
			
			my $other_action_result = RPG::Combat::ActionResult->new(
				defender => $other,
				attacker => $params{character},
				magical_damage => $other_damage_result,
			);
			
			push @others_results, $other_action_result;
		}
		
		$magical_damage_result->other_damages(\@others_results);
	}

	return $magical_damage_result;
}

1;
