use strict;
use warnings;

# Find sectors in a range

package RPG::ResultSet::RowsInSectorRange;

use RPG::Map;
use RPG::Exception;

use Data::Dumper;
use Carp;

# Find a rows in range of sectors from a specified base point (excluding a row at the base point). Params are:
# * resultset - the result set to use for searching
# * relationship - the name of the relationship joining on the the Land table
# * base_point - a hashref containing the x and y coords to base the search
# * search_range - the range to search on (initially)
# * increment_search_by - amount to increment the range by if no rows were found in that range (set to 0 to prevent search incrementing)
# * max_range - (optional) maximum range to search.. if not passed, searches infinitely (which could result in an infintite loop)
#                 throws an exception if the maximum range is reached
# * criteria - (optional) hashref extra critiera to include in the search
# * attrs - (optional) hashref extra attrs to include in the search
sub find_in_range {
    my $package             = shift;
    my $resultset           = shift || confess "Resultset not supplied";
    my $relationship        = shift || confess "Relationship not supplied";
    my $base_point          = shift || confess "Base point not supplied";
    my $search_range        = shift // confess "Search range not supplied";
    my $increment_search_by = shift // confess "Increment search by not supplied";
    my $max_range           = shift;
    my $criteria = shift // {};
    my $attrs = shift // {};

    my @rows_in_range;

    while ( !@rows_in_range ) {
        my ( $start_point, $end_point ) = RPG::Map->surrounds( $base_point->{x}, $base_point->{y}, $search_range, $search_range, );

        # TOOD: should check this isn't already set
        $attrs->{prefetch} = $relationship unless $relationship eq 'me';

        @rows_in_range = $resultset->search(
            {
                %$criteria,
                $relationship . '.x' => { '>=', $start_point->{x}, '<=', $end_point->{x},},
                $relationship . '.y' => { '>=', $start_point->{y}, '<=', $end_point->{y}, },
                -nest => [
                    $relationship . '.x' => {'!=', $base_point->{x}},
                    $relationship . '.y' => {'!=', $base_point->{y}},
                ],
            },
            {
                %$attrs
            },
        );

        last if $increment_search_by == 0;

        # Increase the search range (if we haven't found anything)
        $search_range += $increment_search_by;
        
        if (defined $max_range && ! @rows_in_range && $search_range >= $max_range) {
            die RPG::Exception->new(
                message => "Can't find any rows in the sector range",
                type    => 'find_in_range_error',
            );
        }        
        
    }

    return @rows_in_range;
}

1;
