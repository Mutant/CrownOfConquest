package RPG::C::Magic::Mage;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Games::Dice::Advanced;

sub energy_beam : Private {
	my ($self, $c, $character, $target) = @_;
	
	my $dice_count = int $character->level / 5 + 1;
	
	my $beam = Games::Dice::Advanced->roll($dice_count . "d8");
	
	my $target_creature = $c->stash->{creatures}{$target};
	$target_creature->change_hit_points(-$beam);
	$target_creature->update;
	
	my $msg = $character->character_name . " cast Energy Beam on " . $target_creature->name . ", zapping him for $beam hit points.";	
	
	$msg .= " " . $target_creature->name . " was killed!" if $target_creature->is_dead;
	
	return $msg;
}

sub confuse : Private {
	my ($self, $c, $character, $target) = @_;
	
	my $defence_modifier = 0 - $character->level;
	my $duration = 2 * (int $character->level / 5 + 1);
	
	$c->forward('/magic/create_effect',
		[{
			target_type => 'creature',
			target_id => $target,
			effect_name => 'Confused',
			duration => $duration,
			modifier => $defence_modifier,
			combat => 1,
			modified_state => 'defence_factor',
		}]
	);
	
	my $target_char = $c->stash->{creatures}{$target};
	return $character->character_name . " cast Confuse on " . $target_char->name . ", confusing it for $duration rounds";
}

1;