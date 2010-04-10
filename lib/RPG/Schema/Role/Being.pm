package RPG::Schema::Role::Being;

use Moose::Role;

use Lingua::EN::Gender qw();

requires 'group_id';

sub health {
	my $self = shift;

    # Would be nice to 'require' the hit point methods in the role, but because they're auto-generated by DBIC (for at least some consumers),
    #  we can't.
	my $ratio = $self->hit_points_current / $self->hit_points_max;
	
	# TODO: hmm, maybe these messages belongs in the view
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

sub pronoun {
    my $self = shift;
    
    my $pronoun_type = shift;
    
    return Lingua::EN::Gender::pronoun($pronoun_type, $self->gender);
    
    
}


1;