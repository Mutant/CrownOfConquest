package RPG::Combat::MagicalDamage::Ice;

use strict;
use warnings;

use Games::Dice::Advanced;

sub apply {
	my $self   = shift;
	my %params = @_;

	my $magical_damage_result = RPG::Combat::MagicalDamageResult->new(
		type => 'Ice',
	);

	my $roll         = 2 * $params{level};
	my $extra_damage = Games::Dice::Advanced->roll( '1d' . $roll );

	if ($params{opponent}->hit_with_resistance('Ice', $extra_damage, $params{character})) {
		$magical_damage_result->resisted(1);
		return $magical_damage_result;
	}	    

	$magical_damage_result->extra_damage($extra_damage);

	unless ( $params{opponent}->is_dead ) {
		my $modifier = -0.5;
		my $duration = int( ( $params{level} + 3 ) / 2 );

		$params{schema}->resultset('Effect')->create_effect(
			{
				target         => $params{opponent},
				effect_name    => 'Frozen',
				duration       => $duration,
				modifier       => $modifier,
				combat         => 1,
				modified_state => 'attack_frequency',
			}
		);

		$magical_damage_result->duration($duration);
		$magical_damage_result->effect('frozen');
	}

	return $magical_damage_result;
}

1;
