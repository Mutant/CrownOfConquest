use strict;
use warnings;

# Find sectors in a range

package RPG::ResultSet::RowsInSectorRange;

use RPG::Map;

use Data::Dumper;

# Find a rows in range of sectors from a specified base point (excluding a row at the base point). Params are:
# * resultset - the result set to use for searching
# * relationship - the name of the relationship joining on the the Land table
# * base_point - a hashref containing the x and y coords to base the search
# * search_range - the range to search on (initially)
# * increment_search_by - amount to increment the range by if no rows were found in that range (set to 0 to prevent search incrementing)
sub find_in_range {
    my $package             = shift;
    my $resultset           = shift;
    my $relationship        = shift;
    my $base_point          = shift;
    my $search_range        = shift;
    my $increment_search_by = shift;

    my @rows_in_range;

    while ( !@rows_in_range ) {
        my ( $start_point, $end_point ) = RPG::Map->surrounds( $base_point->{x}, $base_point->{y}, $search_range, $search_range, );

        @rows_in_range = $resultset->search(
            {
                $relationship . '.x' => { '>=', $start_point->{x}, '<=', $end_point->{x}, '!=', $base_point->{x} },
                $relationship . '.y' => { '>=', $start_point->{y}, '<=', $end_point->{y}, '!=', $base_point->{y} },
            },
            {
                prefetch => $relationship,
            },
        );

        last if $increment_search_by == 0;

        # Increase the search range (if we haven't found anything)
        $search_range += $increment_search_by;
    }

    return @rows_in_range;
}

1;
