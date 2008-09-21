package RPG::Map;

use strict;
use warnings;

use Carp;

# XXX: could be moved into Land schema class?

sub surrounds {
    my $self = shift;
    my $x_base = shift || croak 'x base not supplied';
    my $y_base = shift || croak 'y base not supplied';
    my $x_size = shift || croak 'x size not supplied';
    my $y_size = shift || croak 'y size not supplied';
    
    # XXX: x_size and y_size must both be odd numbers;
    my ($x_start, $y_start) = (_coord_diff($x_base, $x_size, 0), _coord_diff($y_base, $y_size, 0));
    my ($x_end,   $y_end)   = (_coord_diff($x_base, $x_size, 1), _coord_diff($y_base, $y_size, 1));    
    
    return (
        {
            x => $x_start, 
            y => $y_start
        },
        {
            x => $x_end, 
            y => $y_end
        }
    );
    
}

sub _coord_diff {
    my $coord = shift || croak 'coord value not supplied';
    my $size  = shift || croak 'size not supplied';
    my $direction = shift; # 0 = down, 1 = up;
    
    my $factor = (($size-1) / 2);
    
    my $diff;
    if ($direction == 1) {
    	$diff = $coord + $factor;
    }
    else {
    	$diff = $coord - $factor;
    }
    $diff = 1 if $diff <= 0;
    
    return $diff;
}

# Returns a list of sectors next to a given sector, within a given range of co-ordinates
sub get_adjacent_sectors {
	my ($package, $current_x, $current_y, $min_x, $min_y, $max_x, $max_y) = @_;
	
	# Get adjacent squares
    my ($start_point, $end_point) = __PACKAGE__->surrounds(
		$current_x,
		$current_y,
		3,
		3,
	);				
	my ($new_x, $new_y);
	
	my @sectors;
	
	for my $x ($start_point->{x} .. $end_point->{x}) {
		for my $y ($start_point->{y} .. $end_point->{y}) {
			unless ($x == $current_x && $y == $current_y ||
					($x < $min_x  || $x > $max_x  ||
		 			 $y < $min_y  || $y > $max_y)) {
			
				push @sectors, [$x, $y];
			}
		}
	}
	
	return @sectors;	
}
# Checks whether a given coord is within a given range
sub is_in_range {
	my ($package, $coord_to_check, $start_coord, $end_coord) = @_;
	
	if ($coord_to_check->{x} >= $start_coord->{x} && $coord_to_check->{x} <= $end_coord->{x} &&
	    $coord_to_check->{y} >= $start_coord->{y} && $coord_to_check->{y} <= $end_coord->{y}) {
	    
	    return 1;
	}
	
	return 0;
}

1;