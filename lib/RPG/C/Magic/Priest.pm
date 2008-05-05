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
	
	my $effect = $c->model('DBIC::Effect')->find_or_new(
		{
			'character_effect.character_id' => $target,
			effect_name => 'Shield',
		},
		{
			join => 'character_effect',
		}
	);
	
	unless ($effect->in_storage) {
		$effect->insert;
		$c->model('Character_Effect')->create(
			{
				character_id => $target,
				effect_id => $effect->id,
			}
		);	
	}
	
	$effect->time_left($effect->time_left + $duration);
	$effect->modifier($shield_modifier);
	$effect->modified_stat('defence_factor');
	$effect->combat(1);
	$effect->update;
	
	my $target_char = $c->stash->{characters}{$target};
	return $character->character_name . " cast Shield on " . $target_char->character_name . ", protecting him for $duration rounds";
}

1;