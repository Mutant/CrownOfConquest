use strict;
use warnings;
  
package RPG::ResultSet::Combat_Log;
  
use base 'DBIx::Class::ResultSet';

sub get_logs_around_sector {
	my $self = shift;
	my ($start_x, $start_y, $x_size, $y_size, $start_day) = @_;
	
	my @coords = RPG::Map->surrounds($start_x, $start_y, $x_size, $y_size);
	
	return $self->search(
		{
			'land.x'   => {'>=', $coords[0]->{x}},
			'land.x'   => {'<=', $coords[1]->{x}},
			'land.y'   => {'>=', $coords[0]->{y}},
			'land.y'   => {'<=', $coords[1]->{y}},
			'game_day' => {'>=', $start_day}, 
		},
		{
			join => 'land',
			order_by => 'encounter_ended desc',
		},
	);
}

1;