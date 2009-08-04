use strict;
use warnings;

package RPG::ResultSet::Creature_Orb;

use base 'DBIx::Class::ResultSet';

use RPG::ResultSet::RowsInSectorRange;

sub find_in_range {
    my $self                = shift;
    my $base_point          = shift;
    my $search_range        = shift;
    my $increment_search_by = shift;
    my $max_range           = shift;

    return RPG::ResultSet::RowsInSectorRange->find_in_range(
        resultset           => $self,
        relationship        => 'land',
        base_point          => $base_point,
        search_range        => $search_range,
        increment_search_by => $increment_search_by,
        max_range           => $max_range
    );
}

1;
