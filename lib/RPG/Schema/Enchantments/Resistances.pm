package RPG::Schema::Enchantments::Resistances;

use Moose::Role;

with 'RPG::Schema::Enchantments::Interface';

use RPG::Maths;
use List::Util qw(shuffle);

my @types = qw/fire ice poison/;

sub init_enchantment {
	my $self = shift;
	
	my $bonus = RPG::Maths->weighted_random_number(1..20);
	
	my $type = (shuffle @types)[0];
	
	$self->add_to_variables(
		{
			name => 'Resistance Bonus',
			item_variable_value => $bonus,
			item_id => $self->item_id,
		},
	);	
	
	$self->add_to_variables(
		{
			name => 'Resistance Type',
			item_variable_value => $type,
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
	
	return '+' . $self->variable('Resistance Bonus') . '% to Resist ' . ucfirst $self->variable('Resistance Type') ;	
}

sub sell_price_adjustment {
	my $self = shift;
	
	return $self->variable('Resistance Bonus') * 120;	
}

1;