use strict;
use warnings;
  
package RPG::ResultSet::Land;
  
use base 'DBIx::Class::ResultSet';

use Carp;
use Data::Dumper;

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

sub get_party_grid {
	my $self = shift;	
	
	my %params = @_;	 
	 
	return $self->search(
        {
            'x' => {'>=', $params{start_point}->{x},'<=', $params{end_point}->{x}},
            'y' => {'>=', $params{start_point}->{y},'<=', $params{end_point}->{y}},
            'party_id' => [$params{party_id}, undef],
        },
        {
        	prefetch => ['terrain', 'mapped_sector', 'town'],
        	'+select' => [ _get_next_to_coords_column($params{centre_point}->{x}, $params{centre_point}->{y}) ],
        	'+as' => ['next_to_centre'],
        },
    );    
}

# Return a hashref with the criteria for a column that is true/false depending on whether it's next to the x/y coords passed in 
sub _get_next_to_coords_column {
	my ($x, $y) = @_;
	
	croak "x and y not supplied" unless $x && $y;

	return 
		{ '' => 
			'(x >= ' . ($x-1) . ' and x <= ' . ($x+1) . 
        	') and (y >= ' . ($y-1) . ' and y <= ' . ($y+1) .
        	") and (y!=$y or x!=$x)"
	}
}
1;