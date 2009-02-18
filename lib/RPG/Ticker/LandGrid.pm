package RPG::Ticker::LandGrid;

use Mouse;

use Games::Dice::Advanced;
use Data::Dumper;
use Math::Round qw(round);

has 'schema'        => ( isa => 'RPG::Schema', is => 'ro', required  => 1 );
has 'max_x'         => ( isa => 'Int',         is => 'rw', init_args => undef );
has 'max_y'         => ( isa => 'Int',         is => 'rw', init_args => undef );
has 'total_sectors' => ( isa => 'Int',         is => 'rw', init_args => undef );

sub BUILD {
    my $self = shift;

    my $land_rs = $self->schema->resultset('Land')->search( 
        {}, 
        { 
            join => [ 'orb', 'creature_group', 'town' ],
            'select' => ['creature_threat','x','y','creature_group.creature_group_id', 'town.town_id', 'orb.creature_orb_id'], 
        } 
    );

    my $land_by_sector;
    my $max_x        = 0;
    my $max_y        = 0;
    my $sector_count = 0;

    # Could in theory use a HashRefInflator here, but it doesn't seem to load data from joined tables
    my $cursor = $land_rs->cursor;
    while ( my @vals = $cursor->next ) {
        my ($x, $y) = ($vals[1], $vals[2]);
        
        $land_by_sector->[ $x ][ $y ] = {            
            orb            => $vals[5]   ? 1 : 0,
            creature_group => $vals[3] ? 1 : 0,
            town           => $vals[4]           ? 1 : 0,
            ctr            => $vals[0],
            x              => $x,
            y              => $y,
        };
        $max_x = $x if $max_x < $x;
        $max_y = $y if $max_x < $y;
        $sector_count++;
    }

    $self->{land_by_sector} = $land_by_sector;
    $self->max_x($max_x);
    $self->max_y($max_y);
    $self->total_sectors($sector_count);
}

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
