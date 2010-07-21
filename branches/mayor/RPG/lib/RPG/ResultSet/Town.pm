use strict;
use warnings;

package RPG::ResultSet::Town;

use base 'DBIx::Class::ResultSet';

use RPG::ResultSet::RowsInSectorRange;
use Data::Dumper;

sub find_in_range {
    my $self                = shift;
    my $base_point          = shift;
    my $search_range        = shift;
    my $increment_search_by = shift || 0;

    return RPG::ResultSet::RowsInSectorRange->find_in_range(
        resultset           => $self,
        relationship        => 'location',
        base_point          => $base_point,
        search_range        => $search_range,
        increment_search_by => $increment_search_by
    );
}

1;
