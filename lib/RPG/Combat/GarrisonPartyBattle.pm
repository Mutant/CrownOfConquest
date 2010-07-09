package RPG::Combat::GarrisonPartyBattle;

# Battles between garrisons and parties - always in the wilderness

use Moose;

use Data::Dumper;
use Carp;
use List::Util qw(shuffle);

use feature 'switch';

has 'garrison' => ( is => 'rw', isa => 'RPG::Schema::Garrison', required => 1 );
has 'party'    => ( is => 'rw', isa => 'RPG::Schema::Party',    required => 1 );
has 'party_flee_attempt'      => ( is => 'ro', isa => 'Bool',       default => 0 );
has 'initiated_by_opp_number' => ( is => 'ro', isa => 'Maybe[Int]', default => 0 );

with qw/
	RPG::Combat::HasParty
	RPG::Combat::CharactersVsCharacters
	RPG::Combat::Battle
	RPG::Combat::InWilderness
	RPG::Combat::GarrisonBattle
	/;
	
around BUILDARGS => sub {
	my $orig   = shift;
	my $class  = shift;
	my %params = @_;

	$params{character_group_1} = $params{party};
	$params{character_group_2} = $params{garrison};

	return $class->$orig(%params);
};

sub check_for_flee {
	my $self = shift;

	# Check for only party flee
	if ( $self->party_flee_attempt && $self->party_flee(1) ) {
		$self->result->{party_fled} = 1;
		return 1;
	}

	# Check for offline flee attempt
	if ( my $group = $self->check_for_offline_flee ) {
		given ($group->group_type) {
			when ('party') {
				$self->result->{party_fled} = 1;
			}
			when ('garrison') {
				$self->{result}->{garrison_fled} = 1;
				$self->garrison_flee;
			}
		}
		return 1;
	}
}

__PACKAGE__->meta->make_immutable;


1;
