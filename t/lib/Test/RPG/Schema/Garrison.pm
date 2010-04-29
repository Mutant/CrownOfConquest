use strict;
use warnings;

package Test::RPG::Schema::Garrison;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Land;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Garrison;
use Test::RPG::Builder::Creature_Orb;
use Test::RPG::Builder::Town;

sub test_find_fleeable_sectors_all_sectors_clear : Tests(9) {
	my $self = shift;
	
	# GIVEN
	my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, land_id => $land[1]->id );
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, land_id => $land[4]->id, );
	
	# WHEN
	my @fleeable_sectors = $garrison->find_fleeable_sectors();
	
	# THEN
	is(scalar @fleeable_sectors, 8, "8 sectors are fleeable");
	for my $idx (0..8) {
		next if $idx == 4;
		my $in_land_array = grep { $_->id == $land[$idx]->id } @fleeable_sectors;
		is(	$in_land_array, 1, "Correct sector returned");
	}
}

sub test_find_fleeable_sectors_some_sectors_occupied : Tests(6) {
	my $self = shift;
	
	# GIVEN
	my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, land_id => $land[1]->id );
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, land_id => $land[4]->id, );
	my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $land[1]->id );
	my $garrison2 = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, land_id => $land[2]->id, );
	my $orb = Test::RPG::Builder::Creature_Orb->build_orb( $self->{schema}, land_id => $land[6]->id, );
	
	# WHEN
	my @fleeable_sectors = $garrison->find_fleeable_sectors();
	
	# THEN
	is(scalar @fleeable_sectors, 5, "5 sectors are fleeable");
	
	my @expected = qw/0 3 5 7 8/;
	
	for my $idx (@expected) {
		my $in_land_array = grep { $_->id == $land[$idx]->id } @fleeable_sectors;
		is(	$in_land_array, 1, "Correct sector returned");
	}
}

1;