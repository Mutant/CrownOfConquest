# For battles that have one or more parties
package RPG::Combat::HasParty;

use Moose::Role;

use Data::Dumper;

sub deduct_turns {
	my $self  = shift;
	my $party = shift;

	if (($self->combat_log->rounds-1) % $self->config->{combat_rounds_per_turn} == 0) {
		$party->turns( $party->turns - 1 );
		$party->update;
	}
}

1;
