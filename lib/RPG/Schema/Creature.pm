package RPG::Schema::Creature;

use Moose;

with 'RPG::Schema::Role::Being';

use Data::Dumper;
use List::MoreUtils qw(true);

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Creature');

__PACKAGE__->add_columns(qw/creature_id creature_group_id creature_type_id hit_points_current hit_points_max group_order weapon/);

__PACKAGE__->set_primary_key('creature_id');

__PACKAGE__->belongs_to(
    'type',
    'RPG::Schema::CreatureType',
    { 'foreign.creature_type_id' => 'self.creature_type_id' },
);

__PACKAGE__->belongs_to(
    'creature_group',
    'RPG::Schema::CreatureGroup',
    { 'foreign.creature_group_id' => 'self.creature_group_id' },
);

__PACKAGE__->has_many(
    'creature_effects',
    'RPG::Schema::Creature_Effect',
    { 'foreign.creature_id' => 'self.creature_id' },
);

sub group_id {
    my $self = shift;
    
    return $self->creature_group_id;   
}

sub group {
	my $self = shift;
	
	return $self->creature_group;
}

sub gender {
    return 'neuter';   
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
	my $level = shift;
	
	$level ||= $self->type->level;
	
	my $base = $self->_calculate_factor(
		$level,
		RPG::Schema->config->{creature_attack_base}, 
		RPG::Schema->config->{create_attack_factor_increment},
	);
	
    # Apply effects
	my $effect_af = 0;
	
	if (ref $self && $self->isa('RPG::Schema::Creature')) {
	   map { $effect_af += $_->effect->modifier if $_->effect->modified_stat eq 'attack_factor' } $self->creature_effects;
	}
	
	return $base + $effect_af;
}

sub defence_factor {
	my $self = shift;
	my $level = shift;
	
	$level ||= $self->type->level;
	
	my $base = $self->_calculate_factor(
		$level,
		RPG::Schema->config->{creature_defence_base}, 
		RPG::Schema->config->{create_defence_factor_increment},
	);

    # Apply effects
	my $effect_df = 0;
	
	if (ref $self && $self->isa('RPG::Schema::Creature')) {
	   map { $effect_df += $_->effect->modifier if $_->effect->modified_stat eq 'defence_factor' } $self->creature_effects;
	}
	
	return $base + $effect_df;
}

sub _calculate_factor {
	my $self  = shift;
	my $level = shift;
	my $base = shift;
	my $increment = shift;
	
	
	my $additional = 0;
    my $step = RPG::Schema->config->{creature_factor_level_increase_step} || 5;
        
	my $step_counter = 0;
	
	while ($level > ($step_counter * $step)) {
	   my $levels_to_add = $level - ($step_counter * $step); 
	   $levels_to_add = $levels_to_add > $step ? $step : $levels_to_add;	   
	   $levels_to_add-- if $step_counter == 0;
	   
	   $additional+=int ($levels_to_add * ($increment + $step_counter));
	   $step_counter++;
	}
	
	
	return $base + $additional;	
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
	my $level = shift;
	
	$level ||= $self->type->level;	
	
	my $effect_dam = 0;
	if (ref $self && $self->isa('RPG::Schema::Creature')) {
	   map { $effect_dam += $_->effect->modifier if $_->effect->modified_stat eq 'damage' } $self->creature_effects;
	}
	
	return int ($level * 1.5 + $effect_dam);	
}

sub is_character {
	return 0;	
}

sub execute_attack {
	return;
}

sub execute_defence {
	return;
}

sub change_hit_points {
	my $self = shift;
	my $amount = shift;
	
	$self->hit_points_current($self->hit_points_current + $amount);
	$self->hit_points_current($self->hit_points_max)
		if $self->hit_points_current > $self->hit_points_max;
		
	$self->hit_points_current(0) if $self->hit_points_current < 0;
	
	return;	
}

sub number_of_attacks {
	my $self = shift;
	my @attack_history = @_;
	
	my $attack_allowed = 1;
	
	my $modifier = 0;
	map { $modifier += $_->effect->modifier if $_->effect->modified_stat eq 'attack_frequency' } $self->creature_effects;
	
	if ($modifier > 0) {
		my $offset = 0-$modifier;
		$offset = scalar @attack_history if $modifier > scalar @attack_history;
		
		my @recent = splice @attack_history, $offset;
		
		my $count = true { $_ == 0; } @recent;
		
		if ($count < $modifier) {
			$attack_allowed = 0;	
		}
	}
	
	return $attack_allowed;
		
}

1;