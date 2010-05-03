use strict;
use warnings;

package Test::RPG::C::Garrison;

__PACKAGE__->runtests unless caller();

use base qw(Test::RPG::DB);

use Test::MockObject;
use Test::More;
use Test::Exception;

use RPG::C::Garrison;

use Data::Dumper;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Garrison;

sub test_remove : Tests(6) {
	my $self = shift;
	
	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, character_count => 2 );
	
	$self->{config}{max_party_characters} = 4;
	
	$self->{stash}{garrison} = $garrison;
	$self->{stash}{party} = $party;
	
	$self->{mock_forward}{'/party/main'} = sub {};
	
	# WHEN
	RPG::C::Garrison->remove( $self->{c} );
	
	# THEN
	$garrison->discard_changes;
	is($garrison->in_storage, 0, "Garrison deleted");
	my @characters = $party->characters;
	is(scalar @characters, 4, "4 characters still in party");
	
	foreach my $character (@characters) {
		is($character->garrison_id, undef, "Character no longer in garrison");	
	}	
		
}

sub test_remove_failed_because_of_max_chars : Tests(3) {
	my $self = shift;
	
	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 3 );
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, character_count => 2 );
	
	$self->{config}{max_party_characters} = 4;
	
	$self->{stash}{garrison} = $garrison;
	$self->{stash}{party} = $party;
	
	# WHEN
	RPG::C::Garrison->remove( $self->{c} );
	
	# THEN
	$garrison->discard_changes;
	is($garrison->in_storage, 1, "Garrison not deleted");
	my @characters = $party->characters;
	is(scalar @characters, 5, "5 characters still in party");
	
	my @gar_chars = $garrison->characters;
	is(scalar @gar_chars, 2, "Still two chars in garrison");	
		
}

1;