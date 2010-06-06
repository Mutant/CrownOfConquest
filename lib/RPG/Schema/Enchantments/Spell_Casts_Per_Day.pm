package RPG::Schema::Enchantments::Spell_Casts_Per_Day;

use Moose::Role;

with 'RPG::Schema::Enchantments::Interface';

use feature 'switch';

sub init_enchantment {
	my $self = shift;
	
	$self->add_to_variables(
		{
			name => 'Spell',
			item_variable_value => 'Heal',
			item_id => $self->item_id,
		},
	);

	$self->add_to_variables(
		{
			name => 'Casts Per Day',
			item_variable_value => 2,
			max_value => 2,
			item_id => $self->item_id,
		},
	);
	
	$self->add_to_variables(
		{
			name => 'Spell Level',
			item_variable_value => 2,
			max_value => 2,
			item_id => $self->item_id,
		},
	);	
}

sub is_usable {
	my $self = shift;
	my $combat = shift;
	
	return 0 if $self->item->variable('Casts Per Day') <= 0;
	
	return 1 if $combat && $self->spell->combat;
	
	return 1 if ! $combat && $self->spell->non_combat;
	
	return 0;
}

sub must_be_equipped {
	return 1;	
}

sub label {
	my $self = shift;
	
	return $self->item->display_name . " (" . $self->item->variable('Spell') . " (" .
		$self->item->variable('Casts Per Day') . "))";	
}

sub tooltip {
	my $self = shift;
	
	my $item = $self->item;
	
	my $times;
	given ($item->variable('Casts Per Day')) {
		when (1) {
			$times = 'once';
		}
		when (2) {
			$times = 'twice';
		}
		default {
			$times = $_ . ' times';
		}
	}
	
	return "Cast " . $item->variable('Spell') . ' (level ' . $item->variable('Spell Level') . ') ' .
		"$times per day"; 
}

sub target {
	my $self = shift;
	
	return $self->spell->target;
}

sub spell {
	my $self = shift;
	
	return $self->result_source->schema->resultset('Spell')->find(
		{
			spell_name => $self->item->variable('Spell'),
		},
	);
}

sub use {
	my $self = shift;
	my $target = shift || confess "Target not supplied";
	
	my $casts_per_days = $self->item->variable_row('Casts Per Day');
	
	confess "No casts left today" unless $casts_per_days->item_variable_value > 0;
	
	my $result = $self->spell->cast_from_action($self->item->belongs_to_character, $target, $self->item->variable('Spell Level'));
	
	$casts_per_days->decrement_item_variable_value;
	$casts_per_days->update;
	
	return $result;	
}

sub new_day {
	my $self = shift;
	
	my $casts_per_days = $self->item->variable_row('Casts Per Day');
	$casts_per_days->item_variable_value($casts_per_days->max_value);
	$casts_per_days->update;
	
	return;	
}

sub sell_price_adjustment {
	my $self = shift;
	
	my $item = $self->item;
	
	my $step = ($item->variable('Casts Per Day') + $item->variable('Spell Level')) * 60;
	
	return 120 + $step; 	
}

1;