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

1;