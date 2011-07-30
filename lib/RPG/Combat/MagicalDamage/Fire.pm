package RPG::Combat::MagicalDamage::Fire;

use strict;
use warnings;

use base qw(RPG::Combat::MagicalDamage);

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

	if ( $self->opponent_resisted( $params{opponent}, 'Fire' ) ) {
		$magical_damage_result->resisted(1);
		return $magical_damage_result;
	}

	my $roll         = 2 * $params{level};
	my $extra_damage = Games::Dice::Advanced->roll( '1d' . $roll ) + 2;

	$params{opponent}->hit($extra_damage, $params{character});

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
			
			if ( $self->opponent_resisted( $other, 'Fire' ) ) {
				$other_damage_result->resisted(1);	
			}
			else {
				my $other_damage = Games::Dice::Advanced->roll( '1d' . $other_roll );
				$other_damage_result->extra_damage($other_damage);
				$other->hit($other_damage, $params{character});
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
