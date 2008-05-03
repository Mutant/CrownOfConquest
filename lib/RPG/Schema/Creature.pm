use strict;
use warnings;

package RPG::Schema::Creature;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Creature');

__PACKAGE__->add_columns(qw/creature_id creature_group_id creature_type_id hit_points_current hit_points_max group_order/);

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

sub hit {
	my $self = shift;
	my $damage = shift;
	
	my $new_hp_total = $self->hit_points_current - $damage;
	$new_hp_total = 0 if $new_hp_total < 0;
	
	$self->hit_points_current($new_hp_total);
	$self->update;
}

sub attack_factor {
	my $self = shift;
	
	return $self->_calculate_factor($self->type->level,RPG->config->{creature_attack_ratio});
}

sub defence_factor {
	my $self = shift;
	
	return $self->_calculate_factor($self->type->level,RPG->config->{creature_defence_ratio});
}

sub _calculate_factor {
	my $self  = shift;
	my $level = shift;
	my $ratio = shift;
	
	return $ratio + ( RPG->config->{create_level_increment_factor} * ( $level-1 ) * $ratio);	
}

sub name {
	my $self = shift;
	
	return $self->type->creature_type . ' #' . $self->group_order; 
}

sub is_dead {
	my $self = shift;
	
	return $self->hit_points_current <= 0 ? 1 : 0;		
}

sub damage {
	my $self = shift;
	
	return $self->type->level * 2;	
}

sub weapon {
	my $self = shift;
	
	return $self->type->weapon || 'Claws';
}

sub is_character {
	return 0;	
}

sub execute_attack {
	return;
}

1;