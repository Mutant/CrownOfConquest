package RPG::Schema::Enchantments::Indestructible;

use Moose::Role;

with 'RPG::Schema::Enchantments::Interface';

sub init_enchantment {
	my $self = shift;
	
	$self->add_to_variables(
		{
			name => 'Indestructible',
			item_variable_value => '1',
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

1;