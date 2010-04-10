package RPG::Combat::SpellActionResult;

# Class representing the outcome of a combatant's spell during combat

use Moose;

extends 'RPG::Combat::ActionResult';

has 'type' => ( is => 'ro', isa => 'Str', required => 1 );    # TODO: enforce allowed values
has 'duration'   => ( is => 'ro', isa => 'Int' );
has 'time_type'  => ( is => 'ro', isa => 'Str', default => 'round' );
has 'effect'     => ( is => 'ro', isa => 'Str', required => 1 );
has 'spell_name' => ( is => 'ro', isa => 'Str', required => 1 );

1;