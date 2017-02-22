use strict;
use warnings;

package RPG::ResultSet::Mapped_Sectors;

use base 'DBIx::Class::ResultSet';

use RPG::ResultSet::RowsInSectorRange;
use Data::Dumper;

sub find_in_range {
    my $self         = shift;
    my $party_id     = shift;
    my $base_point   = shift;
    my $search_range = shift;

    return RPG::ResultSet::RowsInSectorRange->find_in_range(
        resultset           => $self,
        relationship        => 'location',
        base_point          => $base_point,
        search_range        => $search_range,
        increment_search_by => 0,
        include_base_point  => 1,
        rows_as_hashrefs    => 1,
        criteria            => {
            'me.party_id' => $party_id,
          }
    );
}

1;
