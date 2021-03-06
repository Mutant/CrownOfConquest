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
    my $include_base_point  = shift || 0;
    my $max_range           = shift;

    return RPG::ResultSet::RowsInSectorRange->find_in_range(
        resultset           => $self,
        relationship        => 'location',
        base_point          => $base_point,
        search_range        => $search_range,
        increment_search_by => $increment_search_by,
        include_base_point  => $include_base_point,
        max_range           => $max_range,
    );
}

1;
