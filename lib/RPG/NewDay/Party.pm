use strict;
use warnings;

package RPG::NewDay::Party;

sub run {
	my $package = shift;
	my ($config, $schema, $new_day) = @_;
	
	my $party_rs = $schema->resultset('Party')->search( {}, { prefetch => 'characters' });
	
	while (my $party = $party_rs->next) {
		$party->new_day($new_day);		
	}
}

1;