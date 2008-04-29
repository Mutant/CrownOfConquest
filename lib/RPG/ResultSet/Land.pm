use strict;
use warnings;
  
package RPG::ResultSet::Land;
  
use base 'DBIx::Class::ResultSet';

 sub get_x_y_range {
	my ($self) = @_;

    my $range_rec = $self->find(
		{},
		{
			select => [
				{ min => 'x' },
				{ min => 'y' },
				{ max => 'x' },
				{ max => 'y' },
			],
			as => [qw/min_x min_y max_x max_y/],
		},					
	);
	
	return (
		min_x => $range_rec->get_column('min_x'),
		min_y => $range_rec->get_column('min_y'),
		max_x => $range_rec->get_column('max_x'),
		max_y => $range_rec->get_column('max_y'),
	);
}

1;