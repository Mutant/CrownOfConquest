use strict;
use warnings;

package RPG::Position;

my %opposites = (
    'top'    => 'bottom',
    'bottom' => 'top',
    'left'   => 'right',
    'right'  => 'left',
);

sub opposite {
    my $self = shift;
    my $position = shift;
    
    return $opposites{$position};
}

sub opposite_sector {
    my $self = shift;
    my $position = shift;
    my $x = shift;
    my $y = shift;

    my %position_modifier = (
        'top'    => { y => -1 },
        'bottom' => { y => 1 },
        'left'   => { x => -1 },
        'right'  => { x => 1 },
    );

    my $opp_x = $x + ( $position_modifier{ $position }{x} || 0 );
    my $opp_y = $y + ( $position_modifier{ $position }{y} || 0 );

    return ( $opp_x, $opp_y );
}

1;