use strict;
use warnings;
  
package RPG::ResultSet::Creature_Orb;
  
use base 'DBIx::Class::ResultSet';

use RPG::ResultSet::RowsInSectorRange;

sub find_in_range {
	my $self = shift;
	my $base_point = shift;
	my $search_range = shift;
	my $increment_search_by = shift;
	
	return RPG::ResultSet::RowsInSectorRange->find_in_range($self, 'land', $base_point, $search_range, $increment_search_by);
}

1;