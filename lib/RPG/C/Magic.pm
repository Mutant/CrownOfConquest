package RPG::C::Magic;

use strict;
use warnings;
use base 'Catalyst::Controller';

sub cast : Local {
	my ($self, $c, $character, $spell_id, $target) = @_;

	$c->stash->{characters} = { map { $_->id => $_ } $c->stash->{party}->characters };
	
	if ($c->stash->{party}->in_combat_with) {
		$c->stash->{creatures} = { map { $_->id => $_ } $c->stash->{creature_group}->creatures };
	}
	
	die "No spell, target or character. ($character, $spell_id, $target)\n"
		unless $character && $spell_id && $target;
	
	my $spell = $c->model('DBIC::Spell')->find(
		{
   			spell_id => $spell_id,
   			character_id => $character->id,
		},
		{
			prefetch => ['class'],
		},
	);
   
   	die "Spell not found" unless $spell;
   	
   	my $spell_action = lc $spell->spell_name;
   	$spell_action =~ s/ /_/g;
   	
   	my $message = $c->forward('/magic/' . lc $spell->class->class_name . '/' . $spell_action,
   		[
   			$character,
   			$target,
   		],
   	);
   	
   	my $memorised_spell = $c->model('DBIC::Memorised_Spell')->find(
   		{
   			spell_id => $spell->id,
   			character_id => $character->id,
   		}
   	);
   	$memorised_spell->number_cast_today($memorised_spell->number_cast_today+1);
   	$memorised_spell->update;
   	
   	return $message;
}

sub create_effect : Private {
	my ($self, $c, $params) = @_;

	my ($relationship_name, $search_field, $joining_table);
	
	if ($params->{target_type} eq 'character') {
		$search_field = 'character_id';
		$relationship_name = 'character_effect';
		$joining_table = 'Character_Effect';
	}
	else {
		$search_field = 'creature_id';
		$relationship_name = 'creature_effect';
		$joining_table = 'Creature_Effect';
	}
	
	my $effect = $c->model('DBIC::Effect')->find_or_new(
		{
			"$relationship_name.$search_field" => $params->{target_id},
			effect_name => $params->{effect_name},
		},
		{
			join => $relationship_name,
		}
	);
	
	unless ($effect->in_storage) {
		$effect->insert;
		$c->model('DBIC::' . $joining_table)->create(
			{
				$search_field => $params->{target_id},
				effect_id => $effect->id,
			}
		);	
	}
	
	$effect->time_left($effect->time_left + $params->{duration});
	$effect->modifier($params->{modifier});
	$effect->modified_stat($params->{modified_state});
	$effect->combat($params->{combat});
	$effect->update;
}

1;