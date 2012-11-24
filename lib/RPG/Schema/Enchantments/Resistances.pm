package RPG::Schema::Enchantments::Resistances;

use Moose::Role;

with 'RPG::Schema::Enchantments::Interface';

use RPG::Maths;
use List::Util qw(shuffle);
use Games::Dice::Advanced;

my @types = qw/fire ice poison/;

sub init_enchantment {
	my $self = shift;
	
	my $bonus;	
	my $type;
	
	if (Games::Dice::Advanced->roll('1d100') <= 5) {
	   $type = 'all';
	   $bonus = RPG::Maths->weighted_random_number(1..10);   
	}
	else {
	   $type = (shuffle @types)[0];
	   $bonus = RPG::Maths->weighted_random_number(1..20);
	}
	
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
	
	my $label = '';
	if ($self->variable('Resistance Type') eq 'all') {
	    $label = ' All Resistances';
	}
	else {
	    $label = 'Resist ' . ucfirst $self->variable('Resistance Type');
	}
	
	return '+' . $self->variable('Resistance Bonus') . "% to $label";	
}

sub sell_price_adjustment {
	my $self = shift;
	
	if ($self->variable('Resistance Type') eq 'all') {
	   return $self->variable('Resistance Bonus') * 310; 
	}
	else {
	   return $self->variable('Resistance Bonus') * 120;
	}	
}

1;