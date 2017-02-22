use strict;
use warnings;

package RPG::ResultSet::Town_History;

use base 'DBIx::Class::ResultSet';

sub recent_history {
    my $self        = shift;
    my $town_id     = shift;
    my $type        = shift;
    my $current_day = shift;
    my $day_range   = shift;

    return $self->search(
        {
            town_id => $town_id,
            'day.day_number' => { '<=', $current_day, '>=', $current_day - $day_range },
            type => $type,
        },
        {
            prefetch => 'day',
            order_by => 'day_number desc, date_recorded',
        }
    );
}

1;
