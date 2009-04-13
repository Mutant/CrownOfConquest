package RPG::Ticker::BaseGrid;

use Mouse;

use Games::Dice::Advanced;
use Data::Dumper;
use Math::Round qw(round);

has 'schema'        => ( isa => 'RPG::Schema', is => 'ro', required  => 1 );
has 'max_x'         => ( isa => 'Int',         is => 'rw', init_args => undef );
has 'max_y'         => ( isa => 'Int',         is => 'rw', init_args => undef );
has 'total_sectors' => ( isa => 'Int',         is => 'rw', init_args => undef );

sub get_land_at_location {
    my $self = shift;
    my $x    = shift;
    my $y    = shift;

    return $self->{land_by_sector}->[$x][$y];
}

sub get_sectors_within_range {
    my $self        = shift;
    my $start_point = shift;
    my $end_point   = shift;

    confess "Invalid start or end point" unless ref $start_point && ref $end_point;

    my @sectors;

    for my $x ( $start_point->{x} .. $end_point->{x} ) {
        for my $y ( $start_point->{y} .. $end_point->{y} ) {
            my $sector = $self->get_land_at_location( $x, $y );
            push @sectors, $sector if $sector;
        }
    }

    return @sectors;
}

sub get_random_sector_within_range {
    my $self        = shift;
    my $start_point = shift;
    my $end_point   = shift;

    my $x = Games::Dice::Advanced->roll( '1d' . ($end_point->{x} - $start_point->{x} + 1) ) + $start_point->{x} - 1;
    my $y = Games::Dice::Advanced->roll( '1d' . ($end_point->{y} - $start_point->{y} + 1) ) + $start_point->{y} - 1;

    return $self->get_land_at_location( $x, $y );
}

sub set_land_object {
    my $self   = shift;
    my $object = shift;
    my $x      = shift;
    my $y      = shift;

    my $sector = $self->get_land_at_location( $x, $y );

    $sector->{$object} = 1;
}

sub clear_land_object {
    my $self   = shift;
    my $object = shift;
    my $x      = shift;
    my $y      = shift;

    my $sector = $self->get_land_at_location( $x, $y );

    $sector->{$object} = 0;
}

1;