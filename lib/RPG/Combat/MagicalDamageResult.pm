package RPG::Combat::MagicalDamageResult;

# Class representing the outcome of extra magical damage as part of an attack

use Moose;

has 'type' => ( is => 'ro', isa => 'Str', required => 1 );    # TODO: enforce allowed values
has 'duration'     => ( is => 'rw', isa => 'Int' );
has 'effect'       => ( is => 'rw', isa => 'Str' );
has 'extra_damage' => ( is => 'rw', isa => 'Int' );
has 'resisted' => ( is => 'rw', isa => 'Bool', default => 0 );
has 'other_damages' => (is => 'rw', isa => 'ArrayRef[RPG::Combat::ActionResult]');

__PACKAGE__->meta->make_immutable;

1;
