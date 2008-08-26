use strict;
use warnings;
  
package RPG::ResultSet::Party;
  
use base 'DBIx::Class::ResultSet';

sub average_stat {
	my $self = shift;
	my $party_id = shift;
	my $stat = shift;
	
	my ($rec) = $self->search(
		{
			'me.party_id' => $party_id,
		},
		{
			join => 'characters',
			select => { avg => 'characters.' . $stat },
			as => 'avg',
		}
	);
	
	return $rec->get_column('avg');
}
	
	
1;