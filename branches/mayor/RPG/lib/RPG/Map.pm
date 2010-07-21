package RPG::Map;

use strict;
use warnings;

use Carp;

use Math::Round qw(round);

sub surrounds {
	my $self           = shift;
	my $x_base         = shift || confess 'x base not supplied';
	my $y_base         = shift || confess 'y base not supplied';
	my $x_size         = shift || confess 'x size not supplied';
	my $y_size         = shift || confess 'y size not supplied';
	my $allow_negative = shift || 0;

	# XXX: x_size and y_size must both be odd numbers;
	my ( $x_start, $y_start ) = ( _coord_diff( $x_base, $x_size, 0, $allow_negative ), _coord_diff( $y_base, $y_size, 0, $allow_negative ) );
	my ( $x_end,   $y_end )   = ( _coord_diff( $x_base, $x_size, 1, $allow_negative ), _coord_diff( $y_base, $y_size, 1, $allow_negative ) );

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

# Get the surrounds based on the range from the center square, rather than an x by y size
# If only one param is passed in as range, it's assumed to be the same for both x and y
sub surrounds_by_range {
	my $self    = shift;
	my $x_base  = shift || confess 'x base not supplied';
	my $y_base  = shift || confess 'y base not supplied';
	my $x_range = shift;
	confess 'x size not supplied' unless defined $x_range;
	my $y_range = shift || $x_range;

	$x_range = $x_range * 2 + 1;
	$y_range = $y_range * 2 + 1;

	return $self->surrounds( $x_base, $y_base, $x_range, $y_range );
}

sub _coord_diff {
	my $coord = shift || confess 'coord value not supplied';
	my $size  = shift || confess 'size not supplied';
	my $direction      = shift;    # 0 = down, 1 = up;
	my $allow_negative = shift;

	my $factor = ( ( $size - 1 ) / 2 );

	my $diff;
	if ( $direction == 1 ) {
		$diff = $coord + $factor;
	}
	else {
		$diff = $coord - $factor;
	}

	if ( !$allow_negative && $diff <= 0 ) {
		$diff = 1;
	}

	return $diff;
}

# Returns a list of sectors next to a given sector, within a given range of co-ordinates
sub get_adjacent_sectors {
	my ( $package, $current_x, $current_y ) = @_;

	# Get adjacent squares
	my ( $start_point, $end_point ) = $package->surrounds(
		$current_x,
		$current_y,
		3,
		3,
	);
	my ( $new_x, $new_y );

	my @sectors;

	for my $x ( $start_point->{x} .. $end_point->{x} ) {
		for my $y ( $start_point->{y} .. $end_point->{y} ) {
			unless ( $x == $current_x && $y == $current_y ) {

				push @sectors,
					{
					x => $x,
					y => $y,
					};
			}
		}
	}

	return @sectors;
}

# Checks whether a given coord is within a given range
sub is_in_range {
	my ( $package, $coord_to_check, $start_coord, $end_coord ) = @_;

	if (   $coord_to_check->{x} >= $start_coord->{x}
		&& $coord_to_check->{x} <= $end_coord->{x}
		&& $coord_to_check->{y} >= $start_coord->{y}
		&& $coord_to_check->{y} <= $end_coord->{y} )
	{

		return 1;
	}

	return 0;
}

# Get the overlapping sectors in two squares
sub get_overlapping_sectors {
	my ( $package, $first_square, $second_square ) = @_;

	my @overlap;

	for my $first_x ( $first_square->[0]{x} .. $first_square->[1]{x} ) {
		for my $first_y ( $first_square->[0]{y} .. $first_square->[1]{y} ) {
			my $coord_to_test = { x => $first_x, y => $first_y };
			push @overlap, $coord_to_test if $package->is_in_range( $coord_to_test, @{$second_square} );
		}
	}

	return @overlap;
}

# Check whether one coord is immediately adjacent to another
sub is_adjacent_to {
	my ( $package, $first_coord, $second_coord ) = @_;

	my @adjacent_sectors = $package->get_adjacent_sectors( $first_coord->{x}, $first_coord->{y} );

	foreach my $adjacent_sector (@adjacent_sectors) {
		if ( $second_coord->{x} == $adjacent_sector->{x} && $second_coord->{y} == $adjacent_sector->{y} ) {
			return 1;
		}
	}

	return 0;

}

# Return distance between two points
sub get_distance_between_points {
	my $package = shift;
	my $point1  = shift;
	my $point2  = shift;

	my $first_dist  = abs $point1->{x} - $point2->{x};
	my $second_dist = abs $point1->{y} - $point2->{y};

	my $dist = $first_dist > $second_dist ? $first_dist : $second_dist;

	return $dist;
}

# Return a string indicating the direction from one point to another
sub get_direction_to_point {
	my $package = shift;
	my $point1  = shift;
	my $point2  = shift;

	my $x_diff = $point2->{x} - $point1->{x};
	my $y_diff = $point2->{y} - $point1->{y};

	return '' if $x_diff == 0 && $y_diff == 0;

	my ( $x_dir, $y_dir );

	if ( $x_diff < 0 ) {
		$x_dir = 'West';
	}
	elsif ( $x_diff > 0 ) {
		$x_dir = 'East';
	}

	if ( $y_diff < 0 ) {
		$y_dir = 'North';
	}
	elsif ( $y_diff > 0 ) {
		$y_dir = 'South';
	}

	return $x_dir unless $y_diff;
	return $y_dir unless $x_diff;

	# We have both an x and y direction. If one is much bigger than the other, only use that one, otherwise combine them.
	$x_diff = abs $x_diff;
	$y_diff = abs $y_diff;

	if ( $x_diff > $y_diff ) {
		my $factor = $x_diff / $y_diff;
		return $x_dir if $factor > 2;
	}
	if ( $y_diff > $x_diff ) {
		my $factor = $y_diff / $x_diff;
		return $y_dir if $factor > 2;
	}

	return "$y_dir $x_dir";
}

sub adjust_coord_by_direction {
	my $package   = shift;
	my $coord     = shift;
	my $direction = shift;

	my %adjustments = (
		'1' => { y => 1,  x => -1 },
		'2' => { y => 1 },
		'3' => { y => 1,  x => 1 },
		'4' => { x => -1 },
		'6' => { x => 1 },
		'7' => { y => -1, x => -1 },
		'8' => { y => -1 },
		'9' => { y => -1, x => 1 },
	);

	while ( my ( $coord_dir, $adjustment ) = each %{ $adjustments{$direction} } ) {
		$coord->{$coord_dir} += $adjustment;
	}

	return $coord;

}

1;
