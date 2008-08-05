package RPG::C::Magic::Mage;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Games::Dice::Advanced;

sub energy_beam : Private {
	my ($self, $c, $character, $target) = @_;
	
	my $dice_count = int $character->level / 5 + 1;
	
	my $beam = Games::Dice::Advanced->roll($dice_count . "d6");
	
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
	my $duration = 2 * (int $character->level / 2 + 1);
	
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

sub weaken : Private {
	my ($self, $c, $character, $target) = @_;
	
	my $modifier = 0 - $character->level;
	my $duration = 2 * (int $character->level / 3 + 1);
	
	$c->forward('/magic/create_effect',
		[{
			target_type => 'creature',
			target_id => $target,
			effect_name => 'Weakened',
			duration => $duration,
			modifier => $modifier,
			combat => 1,
			modified_state => 'damage',
		}]
	);
	
	my $target_char = $c->stash->{creatures}{$target};
	return $character->character_name . " cast Weaken on " . $target_char->name . ", weakening it for $duration rounds";
}

sub curse : Private {
	my ($self, $c, $character, $target) = @_;
	
	my $modifier = 0 - $character->level;
	my $duration = 2 * (int $character->level / 4 + 1);
	
	$c->forward('/magic/create_effect',
		[{
			target_type => 'creature',
			target_id => $target,
			effect_name => 'Cursed',
			duration => $duration,
			modifier => $modifier,
			combat => 1,
			modified_state => 'attack_factor',
		}]
	);
	
	my $target_char = $c->stash->{creatures}{$target};
	return $character->character_name . " cast Curse on " . $target_char->name . ", cursing it for $duration rounds";
}

sub slow : Private {
	my ($self, $c, $character, $target) = @_;
	
	my $duration = 2 * (int $character->level / 3 + 1);
	
	$c->forward('/magic/create_effect',
		[{
			target_type => 'creature',
			target_id => $target,
			effect_name => 'Slowed',
			duration => $duration,
			modifier => 1,
			combat => 1,
			modified_state => 'attack_frequency',
		}]
	);
	
	my $target_char = $c->stash->{creatures}{$target};
	return $character->character_name . " cast Slow on " . $target_char->name . ", slowing it for $duration rounds";
}

sub entangle : Private {
	my ($self, $c, $character, $target) = @_;
	
	my $duration = 3 + (int $character->level / 5 + 1);
	
	$c->forward('/magic/create_effect',
		[{
			target_type => 'creature',
			target_id => $target,
			effect_name => 'Entangled',
			duration => $duration,
			modifier => $duration,
			combat => 1,
			modified_state => 'attack_frequency',
		}]
	);
	
	my $target_char = $c->stash->{creatures}{$target};
	return $character->character_name . " cast Entangle on " . $target_char->name . ", entangling it for $duration rounds";
}

sub flame : Private {
	my ($self, $c, $character, $target) = @_;
	
	my $dice_count = int $character->level / 3 + 1;
	
	my $flame= Games::Dice::Advanced->roll($dice_count . "d10");
	
	my $target_creature = $c->stash->{creatures}{$target};
	$target_creature->change_hit_points(-$flame);
	$target_creature->update;
	
	my $msg = $character->character_name . " cast Flame on " . $target_creature->name . ", frying him for $flame hit points.";	
	
	$msg .= " " . $target_creature->name . " was killed!" if $target_creature->is_dead;
	
	return $msg;
}

1;