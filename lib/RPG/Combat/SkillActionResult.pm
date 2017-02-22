package RPG::Combat::SkillActionResult;

# Class representing the outcome of a combatant's skill during combat

use Moose;

extends 'RPG::Combat::ActionResult';

has 'skill' => ( is => 'ro', isa => 'Str', required => 1 ); # TODO: enforce allowed values
has 'duration' => ( is => 'ro', isa => 'Int' );

__PACKAGE__->meta->make_immutable;

1;
