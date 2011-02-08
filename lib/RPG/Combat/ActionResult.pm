package RPG::Combat::ActionResult;

# Class representing the outcome of a combatant's action during combat

use Moose;

has 'defender'        => ( is => 'ro', isa => 'Object', required => 1 );
has 'attacker'        => ( is => 'ro', isa => 'Object', required => 1 );
has 'damage'          => ( is => 'ro', isa => 'Int',    default  => 0 );
has 'defender_killed' => ( is => 'ro', isa => 'Bool',   builder  => '_build_defender_killed', lazy => 1 );
has 'no_ammo'         => ( is => 'ro', isa => 'Bool',   default  => 0 );
has 'weapon_broken'   => ( is => 'ro', isa => 'Bool',   default  => 0 );
has 'magical_damage'  => ( is => 'rw', isa => 'RPG::Combat::MagicalDamageResult', required => 0 );

sub _build_defender_killed {
    my $self = shift;

    return $self->defender->can('is_dead') && $self->defender->is_dead;
}

__PACKAGE__->meta->make_immutable;

1;
