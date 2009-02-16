use strict;
use warnings;

package RPG::Schema::CreatureGroup;

use base 'DBIx::Class';

use Carp;
use Data::Dumper;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Creature_Group');

__PACKAGE__->resultset_class('RPG::ResultSet::CreatureGroup');

__PACKAGE__->add_columns(qw/creature_group_id land_id trait_id dungeon_grid_id/);

__PACKAGE__->set_primary_key('creature_group_id');

__PACKAGE__->belongs_to(
    'location',
    'RPG::Schema::Land',
    { 'foreign.land_id' => 'self.land_id' }
);

__PACKAGE__->belongs_to(
    'dungeon_grid',
    'RPG::Schema::Dungeon_Grid',
    { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' }
);

__PACKAGE__->might_have(
    'in_combat_with',
    'RPG::Schema::Party',
    { 'foreign.in_combat_with' => 'self.creature_group_id' }
);

__PACKAGE__->has_many(
    'creatures',
    'RPG::Schema::Creature',
    { 'foreign.creature_group_id' => 'self.creature_group_id' },
    { order_by => 'group_order' },
);

sub initiate_combat {
	my $self = shift;
	my $party = shift || croak "Party not supplied";

    if ($self->land_id && $self->location->orb && $self->location->orb->can_destroy( $party->level) ) {
        # Always attack if there's an orb in the sector, and the party is high enough level to destroy it
        return 1;
    }

	return 0
		if $self->level - $party->level > RPG::Schema->config->{cg_attack_max_level_above_party};
		
	return 0
	   if $party->level - $self->level > RPG::Schema->config->{cg_attack_max_level_below_party}; 

	my $chance = RPG::Schema->config->{creature_attack_chance};
	
	my $roll = Games::Dice::Advanced->roll('1d100');
				
	return $roll < $chance ? 1 : 0;
}

sub creature_summary {
	my $self = shift;
	my $include_dead_creatures = shift || 0;
	my @creatures = $self->creatures;
		
	my %summary;
	
	foreach my $creature (@creatures) {
	    next if ! $include_dead_creatures && $creature->is_dead;
		$summary{$creature->type->creature_type}++;
	}
	
	return \%summary;
}

sub number_alive {
	my $self = shift;
	
	# TODO: possibly check if creatures are already loaded, and use those rather than going to the DB

	return $self->result_source->schema->resultset('Creature')->count({
		hit_points_current => {'>',0},
		creature_group_id => $self->id,	
	});	
}

sub level {
	my $self = shift;
	
	return $self->{level} if $self->{level};
	
	my @creatures = $self->creatures;
	
	return 0 unless @creatures;
	
	my $level_aggr = 0;
	foreach my $creature (@creatures) {
		$level_aggr += $creature->type->level; 
	}
	
	$self->{level} = int ($level_aggr / scalar @creatures);
	
	return $self->{level};
			
}

1;