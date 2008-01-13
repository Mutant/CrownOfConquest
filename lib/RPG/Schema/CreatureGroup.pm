use strict;
use warnings;

package RPG::Schema::CreatureGroup;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Creature_Group');

__PACKAGE__->add_columns(qw/creature_group_id land_id trait_id/);

__PACKAGE__->belongs_to(
    'location',
    'RPG::Schema::Land',
    { 'foreign.land_id' => 'self.land_id' }
);

__PACKAGE__->has_many(
    'creatures',
    'RPG::Schema::Creatures',
    { 'foreign.creature_group_id' => 'self.creature_group_id' },
);

sub initiate_combat {
	my $self = shift;
	my $party = shift || croak "Party not supplied";
	my $chance = shift || croak "Chance of initiating combat not supplied";
	
	my $roll = int rand 100;
	
	return $roll >= $chance;
}

sub creature_summary {
	my $self = shift;
	my @creatures = $self->creatures;
	
	my %summary;
	
	foreach my $creature (@creatures) {
		$summary{$creature->type->creature_type}++;
	}
	
	return %summary;
}

1;