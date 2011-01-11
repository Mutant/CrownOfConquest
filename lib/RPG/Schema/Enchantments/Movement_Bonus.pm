package RPG::Schema::Enchantments::Movement_Bonus;

use Moose::Role;

with 'RPG::Schema::Enchantments::Interface';

sub init_enchantment {
	my $self = shift;
	
	my $bonus = RPG::Maths->weighted_random_number(1..5);
	
	$self->add_to_variables(
		{
			name => 'Movement Bonus',
			item_variable_value => $bonus,
			item_id => $self->item_id,
		},
	);	
}

sub is_usable {
	return 0;	
}

sub must_be_equipped {
	return 1;	
}

sub tooltip {
	my $self = shift;
	
	my $bonus = $self->variable('Movement Bonus');
	
	return "+$bonus to Movement Factor";	
}

sub sell_price_adjustment {
	my $self = shift;
	
	return $self->variable('Movement Bonus') * 175;	
}

1;