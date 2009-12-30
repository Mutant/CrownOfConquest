use strict;
use warnings;

package RPG::ResultSet::Combat_Log;

use base 'DBIx::Class::ResultSet';

use RPG::Map;

sub get_logs_around_sector {
    my $self = shift;
    my ( $start_x, $start_y, $x_size, $y_size, $start_day ) = @_;

    my @coords = RPG::Map->surrounds( $start_x, $start_y, $x_size, $y_size );

    return $self->search(
        {
            'land.x'   => { '>=', $coords[0]->{x}, '<=', $coords[1]->{x} },
            'land.y'   => { '>=', $coords[0]->{y}, '<=', $coords[1]->{y} },
            'day.day_number' => { '>=', $start_day },
        },
        {
            prefetch => ['land', 'day'],
            order_by => 'encounter_ended desc',
        },
    );
}

sub get_offline_log_count {
    my $self  = shift;
    my $party = shift;
    my $date_range_start = shift;
    
    $date_range_start = $party->last_action unless $date_range_start;

    return $self->search(
        {
            $self->_party_criteria($party),
            encounter_ended => { '>', $date_range_start },
        },
    )->count;
}

sub get_recent_logs_for_party {
    my $self  = shift;
    my $party = shift;
    my $logs_count = shift;
    
    return if $logs_count <= 0;
    
    return $self->search(
        {
            $self->_party_criteria($party),
        },
        {
            prefetch => 'day',
            order_by => 'encounter_ended desc',
            rows => $logs_count,
        }
    );
}

sub _party_criteria {
    my $self  = shift;
    my $party = shift;

    return (
        -nest => [
            '-and' => {
                opponent_1_type => 'party',
                opponent_1_id   => $party->id,
            },
            '-and' => {
                opponent_2_type => 'party',
                opponent_2_id   => $party->id,
            }
        ]
    );
}

1;
