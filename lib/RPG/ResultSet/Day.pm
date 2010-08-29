use strict;
use warnings;

package RPG::ResultSet::Day;

use base 'DBIx::Class::ResultSet';

sub find_today {
    my $self = shift;
    
    return $self->find(
        {},
        {
            'rows'     => 1,
            'order_by' => 'day_number desc'
        },
    );
}

sub find_yesterday {
    my $self = shift;
    
    return $self->find(
        {},
        {
            'rows'     => 1,
            'offset'   => 1,
            'order_by' => 'day_number desc'
        },
    );
}

1;