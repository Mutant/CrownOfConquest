package RPG::Schema::Enchantments::Featherweight;

use Moose::Role;

with 'RPG::Schema::Enchantments::Interface';

sub init_enchantment {
	my $self = shift;
	
	my $bonus = RPG::Maths->weighted_random_number(1..5) * 10;
	
	$self->add_to_variables(
		{
			name => 'Featherweight',
			item_variable_value => $bonus,
			item_id => $self->item_id,
		},
	);	
}

sub is_usable {
	return 0;	
}

sub must_be_equipped {
	return 0;	
}

sub tooltip {
	my $self = shift;
	
	return 'Featherweight (' . $self->variable('Featherweight') . '%)';	
}

sub sell_price_adjustment {
	my $self = shift;
	
	return $self->variable('Featherweight') * 5;	
}

1;