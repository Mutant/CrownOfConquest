package RPG::Schema::Enchantments::Spell_Casts_Per_Day;

use Moose::Role;

with 'RPG::Schema::Enchantments::Interface';

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
}

sub is_usable {
	my $self = shift;
	
	return $self->item->variable('Casts Per Day') > 0 ? 1 : 0;	
}

sub must_be_equipped {
	return 0;	
}

sub label {
	my $self = shift;
	
	return $self->item->display_name . " (" . $self->item->variable('Spell') . ")";	
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
	
	my $result = $self->spell->cast_from_action($self->item->belongs_to_character, $target);
	
	$casts_per_days->decrement_item_variable_value;
	$casts_per_days->update;
	
	return $result;	
}

1;