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

sub shield : Private {
	my ($self, $c, $character, $target) = @_;
	
	my $shield_modifier = $character->level;
	my $duration = 2 * (int $character->level / 5 + 1);
	
	$c->forward('/magic/create_effect',
		[{
			target_type => 'character',
			target_id => $target,
			effect_name => 'Shield',
			duration => $duration,
			modifier => $shield_modifier,
			combat => 1,
			modified_state => 'defence_factor',
		}]
	);
	
	my $target_char = $c->stash->{characters}{$target};
	return $character->character_name . " cast Shield on " . $target_char->character_name . ", protecting him for $duration rounds";
}

sub bless : Private {
	my ($self, $c, $character, $target) = @_;
	
	my $modifier = $character->level;
	my $duration = 1 + (int $character->level / 3 + 1);
	
	$c->forward('/magic/create_effect',
		[{
			target_type => 'character',
			target_id => $target,
			effect_name => 'Bless',
			duration => $duration,
			modifier => $modifier,
			combat => 1,
			modified_state => 'attack_factor',
		}]
	);
	
	my $target_char = $c->stash->{characters}{$target};
	return $character->character_name . " cast Bless on " . $target_char->character_name . ", blessing him for $duration rounds";	
}

sub blades : Private {
	my ($self, $c, $character, $target) = @_;
	
	my $modifier = $character->level;
	my $duration = 2 + (int $character->level / 3 + 1);
	
	$c->forward('/magic/create_effect',
		[{
			target_type => 'character',
			target_id => $target,
			effect_name => 'Blades',
			duration => $duration,
			modifier => $modifier,
			combat => 1,
			modified_state => 'damage',
		}]
	);
	
	my $target_char = $c->stash->{characters}{$target};
	return $character->character_name . " cast Blades on " . $target_char->character_name . ", enhancing his weapon for $duration rounds";
}

1;