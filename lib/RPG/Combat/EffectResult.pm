package RPG::Combat::EffectResult;

# Class representing the outcome of a combatant's spell during combat

use Moose;

extends 'RPG::Combat::ActionResult';

has 'effect' => ( is => 'ro', isa => 'Str', default => 0 );
has '+attacker' => ( required => 0 );

1;
