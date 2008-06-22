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

1;