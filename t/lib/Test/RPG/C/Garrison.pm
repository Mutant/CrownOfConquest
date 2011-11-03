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
use Test::RPG::Builder::Day;

sub test_remove : Tests(6) {
	my $self = shift;
	
	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, character_count => 2 );
	
	$self->{config}{max_party_characters} = 4;
	
	$self->{stash}{garrison} = $garrison;
	$self->{stash}{party} = $party;
	$self->{stash}{today} = Test::RPG::Builder::Day->build_day($self->{schema});  
	
	$self->{mock_forward}{'/party/main'} = sub {};
	
	# WHEN
	RPG::C::Garrison->remove( $self->{c} );
	
	# THEN
	$garrison->discard_changes;
	is($garrison->land_id, undef, "Garrison removed");
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

sub test_remove_of_chars_works_when_near_full_party : Tests(7) {
	my $self = shift;
	
	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my @party_chars = $party->characters_in_party;
	my ($orig_party_char_1, $orig_party_char_2) = @party_chars;
	
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, character_count => 2, land_id => $party->land_id);
	my @garrison_chars = $garrison->characters;	
	my ($orig_garrison_char_1, $orig_garrison_char_2) = @garrison_chars;
	
	$self->{config}{max_party_characters} = 2;
	
	$self->{params}{chars_in_garrison} = [$party_chars[0]->id, $garrison_chars[0]->id];
	
	$self->{stash}{garrison} = $garrison;
	$self->{stash}{party} = $party;
	$self->{stash}{party_location} = $party->location;	
	
	# WHEN
	RPG::C::Garrison->update( $self->{c} );
	
	# THEN
	@party_chars = $party->characters_in_party;
	@garrison_chars = $garrison->characters;
	
	is(scalar @party_chars, 2, "Correct number of chars in party");
	is($party_chars[1]->id, $orig_party_char_2->id, "Correct party char 1");
	is($party_chars[0]->id, $orig_garrison_char_2->id, "Correct party char 2");

	is(scalar @garrison_chars, 2, "Correct number of chars in party");
	is($garrison_chars[0]->id, $orig_party_char_1->id, "Correct garrsion char 1");
	is($garrison_chars[1]->id, $orig_garrison_char_1->id, "Correct garrison char 2");
	
	is($self->{stash}{error}, undef, "No error");
}

sub test_add_too_many_chars_to_party : Tests(7) {
	my $self = shift;
	
	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my @party_chars = $party->characters_in_party;
	my ($orig_party_char_1, $orig_party_char_2) = @party_chars;
	
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, character_count => 2, land_id => $party->land_id);
	my @garrison_chars = $garrison->characters;	
	my ($orig_garrison_char_1, $orig_garrison_char_2) = @garrison_chars;
	
	$self->{config}{max_party_characters} = 2;
	
	$self->{params}{chars_in_garrison} = [$garrison_chars[0]->id];
	
	$self->{stash}{garrison} = $garrison;
	$self->{stash}{party} = $party;
	$self->{stash}{party_location} = $party->location;	
	
	# WHEN
	RPG::C::Garrison->update( $self->{c} );
	
	# THEN
	@party_chars = $party->characters_in_party;
	@garrison_chars = $garrison->characters;
	
	is(scalar @party_chars, 2, "Correct number of chars in party");
	is($party_chars[0]->id, $orig_party_char_1->id, "Correct party char 1");
	is($party_chars[1]->id, $orig_party_char_2->id, "Correct party char 2");

	is(scalar @garrison_chars, 2, "Correct number of chars in party");
	is($garrison_chars[0]->id, $orig_garrison_char_1->id, "Correct garrsion char 1");
	is($garrison_chars[1]->id, $orig_garrison_char_2->id, "Correct garrison char 2");
	
	is(defined $self->{stash}{error}, 1, "Error returned");
}

1;