use strict;
use warnings;

package RPG::Schema::Creature;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Creature');

__PACKAGE__->add_columns(qw/creature_id creature_group_id creature_type_id hit_points_current hit_points_max/);

__PACKAGE__->set_primary_key('creature_id');

__PACKAGE__->belongs_to(
    'type',
    'RPG::Schema::CreatureType',
    { 'foreign.creature_type_id' => 'self.creature_type_id' },
);

sub health {
	my $self = shift;
	
	my $ratio = $self->hit_points_current / $self->hit_points_max;
	
	# TODO: hmm, maybe this belongs in the view
	if ($ratio == 1) {
		return 'In Perfect Health';
	}
	elsif ($ratio > 0.75) {
		return 'Slightly Wounded';
	}
	elsif ($ratio > 0.5) {
		return 'Wounded';
	}
	elsif ($ratio > 0.1) {
		return 'Severely Wounded';
	}
	elsif ($ratio > 0) {
		return 'Mortally Wounded';
	}
	else {
		return 'Dead';
	}
}

1;