use strict;
use warnings;
  
package RPG::ResultSet::Town;
  
use base 'DBIx::Class::ResultSet';

# Find a town in range of a specified base point (excluding a town at the base point). Params are:
# * base_point - a hashref containing the x and y coords to base the search
# * search_range - the range to search on (initially)
# * increment_search_by - amount to increment the range by if no towns were found in that range (set to 0 to prevent this) 
sub find_in_range {
	my $self = shift;
	my $base_point = shift;
	my $search_range = shift;
	my $increment_search_by = shift;
	
	my @towns_in_range;
	
    while (! @towns_in_range) {	    
	    my ($start_point, $end_point) = RPG::Map->surrounds(
	    	$base_point->{x},
	    	$base_point->{y},
	    	$search_range,
	    	$search_range,
	    );
	    
	    @towns_in_range = $self->search(
	    	{
	    		'location.x' => {'>=', $start_point->{x}, '<=', $end_point->{x}, '!=', $base_point->{x}},
				'location.y' => {'>=', $start_point->{y}, '<=', $end_point->{y}, '!=', $base_point->{y}},
	    	},
	    	{
	    		prefetch => 'location',
	    	},
	    );
	    
	    last if $increment_search_by == 0;

		# Increase the search range (if we haven't found anything)
	    $search_range+=$increment_search_by;
    }	
    
    return @towns_in_range;
}

1;