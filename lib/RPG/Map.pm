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
    my ($start_point, $end_point) = $package->surrounds(
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

# Return distance between two points
sub get_distance_between_points {
	my $package = shift;
	my $point1 = shift;
	my $point2 = shift;
	
	my $first_dist  = abs $point1->{x} - $point2->{x};
	my $second_dist	= abs $point1->{y} - $point2->{y};
	
	my $dist = $first_dist > $second_dist ? $first_dist : $second_dist;
	
	return $dist;
}

# Return a string indicating the direction from one point to another
sub get_direction_to_point {
	my $package = shift;
	my $point1 = shift;
	my $point2 = shift;
	
	my $x_diff  = $point2->{x} - $point1->{x};
	my $y_diff	= $point2->{y} - $point1->{y};
	
	return '' if $x_diff == 0 && $y_diff == 0;
	
	my ($x_dir, $y_dir);
	
	if ($x_diff < 1) {
		$x_dir = 'West';
	}
	elsif ($x_diff > 1) {
		$x_dir = 'East';	
	}

	if ($y_diff < 1) {
		$y_dir = 'North';
	}
	elsif ($y_diff > 1) {
		$y_dir = 'South';	
	}
	
	return $x_dir unless $y_diff;
	return $y_dir unless $x_diff;
	
	# We have both an x and y direction. If one is much bigger than the other, only use that one, otherwise combine them.
	$x_diff = abs $x_diff;
	$y_diff = abs $y_diff;
	
	if ($x_diff > $y_diff) {
		my $factor = $x_diff / $y_diff;
		return $x_dir if $factor > 2;
	}
	if ($y_diff > $x_diff) {
		my $factor = $y_diff / $x_diff;
		return $y_dir if $factor > 2;
	}
	
	return "$y_dir $x_dir";
}

1;