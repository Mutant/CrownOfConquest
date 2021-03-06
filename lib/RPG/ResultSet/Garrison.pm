use strict;
use warnings;

package RPG::ResultSet::Garrison;

use base 'DBIx::Class::ResultSet';

use RPG::ResultSet::RowsInSectorRange;
use Data::Dumper;

sub find_in_range {
    my $self         = shift;
    my $base_point   = shift;
    my $search_range = shift;
    my $party_id     = shift;

    my %criteria;
    if ($party_id) {
        $criteria{party_id} = $party_id;
    }

    return RPG::ResultSet::RowsInSectorRange->find_in_range(
        resultset           => $self,
        relationship        => 'land',
        base_point          => $base_point,
        search_range        => $search_range,
        increment_search_by => 0,
        include_base_point  => 1,
        rows_as_hashrefs    => 1,
        criteria            => \%criteria,
    );
}

1;
