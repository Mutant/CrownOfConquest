package RPG::C::Magic::Priest;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Games::Dice::Advanced;

sub heal : Private {
	my ($self, $c, $character, $target) = @_;
	
	my $dice_count = int $character->level / 5 + 1;
	
	my $heal = Games::Dice::Advanced->roll($dice_count . "d6");
	
	my $target_char = $c->stash->{characters}{$target};
	$target_char->change_hit_points($heal);
	$target_char->update;
	
	return $character->character_name . " cast Heal on " . $target_char->character_name . " and healed him for $heal hit points";
		
}

1;