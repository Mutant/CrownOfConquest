use strict;
use warnings;

package Test::RPG::Combat::GarrisonPartyBattle;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::More;
use Test::MockObject::Extends;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Garrison;
use Test::RPG::Builder::Day;

sub startup : Tests( startup => 1 ) {
	use_ok 'RPG::Combat::GarrisonPartyBattle';
}

sub setup : Tests(setup) {
	my $self = shift;

	Test::RPG::Builder::Day->build_day( $self->{schema} );
}

sub test_new : Tests(1) {
	my $self = shift;

	# GIVEN
	my $party1   = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $party2   = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party2->id );

	# WHEN
	my $battle = RPG::Combat::GarrisonPartyBattle->new(
		schema         => $self->{schema},
		log            => $self->{mock_logger},
		party          => $party1,
		garrison       => $garrison,
	);

	# THEN
	isa_ok( $battle, 'RPG::Combat::GarrisonPartyBattle', "Object instatiated correctly" );
}

1;
