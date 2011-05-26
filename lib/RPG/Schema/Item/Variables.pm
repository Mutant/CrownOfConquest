# Provides methods to access variables (i.e. for Items or Item_Enchantments)
# The required 'variables' method should return all the variables this object is interested in

package RPG::Schema::Item::Variables;

use Moose::Role;

requires 'variables';

sub variable {
    my $self          = shift;
    my $variable_name = shift;
    my $new_val       = shift;

    my $variable = $self->variable_row( $variable_name, $new_val );

    return unless $variable;

    return $variable->item_variable_value;
}

sub variable_max {
	my $self = shift;
	my $variable_name = shift;
	my $new_max = shift;
	
	my $variable = $self->variable_row( $variable_name );
	
	return unless $variable;
	
	if (defined $new_max) {
		$variable->max_value($new_max);
		$variable->update;
	}
	
	return $variable->max_value;	
}

sub has_variable {
	my $self = shift;
	my $variable_name = shift;
	
	my $variable = $self->variable_row( $variable_name );
	
	return $variable ? 1 : 0;
	
}

sub variable_row {
    my $self          = shift;
    my $variable_name = shift;
    my $new_val       = shift;

	my @vars = $self->variables;

	# Note, due to some edge cases (mostly used in tests), it's possible variables could be accessed before they've actually
	#  been inserted into the db. (i.e. when insert trigger is called). The result gets cached below, meaning we never re-read
	#  them.. so if there are no vars, we just return immediately.
	return unless @vars;

    $self->{_variables} = { map { ($_->name || $_->item_variable_name->item_variable_name) => $_ } @vars }
        unless $self->{_variables};
    my $variable = $self->{_variables}{$variable_name};

    return unless $variable;

    if ($new_val) {
        $variable->item_variable_value($new_val);
        $variable->update;
        $self->{_variables}{$variable_name} = $variable; 
    }

    return $variable;
}

1;