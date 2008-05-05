package RPG::C::Magic;

use strict;
use warnings;
use base 'Catalyst::Controller';

sub cast : Local {
	my ($self, $c, $character, $spell_id, $target) = @_;
	
	if ($c->req->param('spell_id')) {
		$character    = $c->model('DBIC::Character')->find($c->req->param('character_id'));
		$spell_id     = $c->req->param('spell_id');
		$target       = $c->req->param('target');
	}
	
	my $spell = $c->model('DBIC::Spell')->find(
		{
   			spell_id => $spell_id,
   			character_id => $character->id,
		},
		{
			prefetch => ['memorised_by_characters', 'class'],
		},
	);
   
   	$c->error("Spell not found"), return unless $spell;
   	
   	my $message = $c->forward('/magic/' . lc $spell->class->class_name . '/' . lc $spell->spell_name,
   		[
   			$character,
   			$target,
   		],
   	);
   	
   	my ($memorised_spell) = $spell->memorised_by_characters;
   	$memorised_spell->number_cast_today($memorised_spell->number_cast_today+1);
   	$memorised_spell->update;
   	
   	return $message;
}

1;