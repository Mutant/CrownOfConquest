use strict;
use warnings;

package Test::RPG::C::Garrison;

__PACKAGE__->runtests unless caller();

use base qw(Test::RPG::DB);

use Test::MockObject;
use Test::More;
use Test::Exception;
use Try::Tiny;

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

sub test_character_move_from_party_to_garrison : Tests(16) {
	my $self = shift;
	
	# GIVEN
	my @tests = (
	   {
	       chars_in_party => 2,
	       chars_in_garrison => 1,
	       swap => 0,
	       description => "Move char from party to garrison",
	   },
	   {
	       chars_in_party => 2,
	       chars_in_garrison => 1,
	       swap => 1,
	       description => "Swap char from party to garrison",
	   },
	   {
	       chars_in_party => 2,
	       chars_in_garrison => 8,
	       error_expected => qr{^Garrison full},
	       swap => 0,
	       description => "Move char from party to garrison, but garrison full",
	   },
	   {
	       chars_in_party => 2,
	       chars_in_garrison => 8,
	       swap => 1,
	       description => "Swap char from party to garrison, when garrison full",
	   },	   
	   {
	       chars_in_party => 1,
	       chars_in_garrison => 1,
	       error_expected => qr{^Can't remove last living character from party},
	       swap => 0,
	       description => "Move char from party to garrison, but party empty",
	   },
	   {
	       chars_in_party => 1,
	       chars_in_garrison => 1,
	       swap => 1,
	       description => "Swap char from party to garrison, when party empty",
	   },	
	   {
	       chars_in_party => 2,
	       dead_chars_in_party => 1,
	       chars_in_garrison => 1,
	       error_expected => qr{^Can't remove last living character from party},
	       swap => 0,
	       description => "Move char from party to garrison, but party empty (with dead chars)",
	   },
	   {
	       chars_in_party => 2,
	       chars_in_garrison => 1,
	       move_from_garrison => 1,
	       error_expected => qr{^Attempting to move character into garrison from outside party},
	       swap => 0,
	       description => "Char moving into garrison is not in party",
	   },	 
	   {
	       chars_in_party => 2,
	       chars_in_garrison => 1,
	       error_expected => qr{^Attempting to swap out char not in garrison},
	       swap => 1,
	       swap_with_party => 1, 
	       description => "Swap char with one not in the garrison",
	   },	       
	);
	
	foreach my $test (@tests) {
	   undef $self->{params};
	   diag $test->{description};
	    
	   my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => $test->{chars_in_party} );
	   my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, character_count => $test->{chars_in_garrison} );
	   
	   if ($test->{dead_chars_in_party}) {
	       my @chars = $party->members;
	       for my $idx (1..$test->{dead_chars_in_party}) {
	           $chars[$idx-1]->update( { hit_points => 0 } );	           
	       }   
	   }
	   
	   $self->{stash}{garrison} = $garrison;
	   $self->{stash}{party} = $party;
	   
	   my $group_to_move_from = $test->{move_from_garrison} ? $garrison : $party;
	   my $char_to_move_in = (grep { ! $_->is_dead } $group_to_move_from->members)[0];
	   $self->{params}{character_id} = $char_to_move_in->id;
	   $self->{params}{to} = 'garrison';
	   
	   my $char_to_swap_out;
	   if ($test->{swap}) {
	       my $group_to_swap_from = $test->{swap_with_party} ? $party : $garrison;
	       $char_to_swap_out = ($group_to_swap_from->members)[0];
	       $self->{params}{swapped_char_id} = $char_to_swap_out->id;
	   }
	   
	   # WHEN
	   my $error;
	   try {
	       RPG::C::Garrison->character_move( $self->{c} );
	   }
	   catch {
	       $error = $_;
	   };
	   
	   # THEN
	   if ($test->{error_expected}) {
	       like($error, $test->{error_expected}, "Correct error message was received") or diag Dumper $self->{params};
	       next;
	   }
	   
	   is($error, undef, "No error, as expected");
	   
	   $char_to_move_in->discard_changes;
	   is($char_to_move_in->garrison_id, $garrison->id, "Party char was moved into garrison");
	   
	   if ($char_to_swap_out) {
	       $char_to_swap_out->discard_changes;
	       is($char_to_swap_out->garrison_id, undef, "Garrison char was swapped out of garrison");   
	   }
	   
	}    
}

sub test_character_move_from_garrison_to_party : Tests() {
	my $self = shift;
	
	# GIVEN
	my @tests = (
	   {
	       chars_in_party => 1,
	       chars_in_garrison => 2,
	       swap => 0,
	       description => "Move char from garrison to party",
	   },
	   {
	       chars_in_party => 1,
	       chars_in_garrison => 2,
	       swap => 1,
	       description => "Swap char from garrison to party",
	   },
	   {
	       chars_in_party => 8,
	       chars_in_garrison => 2,
	       error_expected => qr{^Party full},
	       swap => 0,
	       description => "Move char from garrison to party, but party full",
	   },
	   {
	       chars_in_party => 8,
	       chars_in_garrison => 2,
	       swap => 1,
	       description => "Swap char from garrison to party, when party full",
	   },	   
	   {
	       chars_in_party => 1,
	       chars_in_garrison => 1,
	       error_expected => qr{^Can't remove last living character from garrison},
	       swap => 0,
	       description => "Move char from garrison to party, but garrison empty",
	   },
	   {
	       chars_in_party => 1,
	       chars_in_garrison => 1,
	       swap => 1,
	       description => "Swap char from garrison to party, when garrison empty",
	   },	
	   {
	       chars_in_party => 2,
	       chars_in_garrison => 2,
	       dead_chars_in_garrison => 1,
	       error_expected => qr{^Can't remove last living character from garrison},
	       swap => 0,
	       description => "Move char from garrison to party, but garrison empty (with dead chars)",
	   },
	   {
	       chars_in_party => 2,
	       chars_in_garrison => 2,
	       move_from_party => 1,
	       error_expected => qr{^Attempting to move character out of garrison when not in garrison},
	       swap => 0,
	       description => "Char moving out of garrison is not in garrison",
	   },	 
	   {
	       chars_in_party => 2,
	       chars_in_garrison => 2,
	       error_expected => qr{^Attempting to swap out char not in party},
	       swap => 1,
	       swap_with_garrison => 1, 
	       description => "Swap char with one not in the party",
	   },	       
	);
	
	foreach my $test (@tests) {
	   undef $self->{params};
	   diag $test->{description};
	    
	   my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => $test->{chars_in_party} );
	   my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, character_count => $test->{chars_in_garrison} );
	   
	   if ($test->{dead_chars_in_garrison}) {
	       my @chars = $garrison->members;
	       for my $idx (1..$test->{dead_chars_in_garrison}) {
	           $chars[$idx-1]->update( { hit_points => 0 } );	           
	       }   
	   }
	   
	   $self->{stash}{garrison} = $garrison;
	   $self->{stash}{party} = $party;
	   
	   my $group_to_move_from = $test->{move_from_party} ? $party : $garrison;
	   my $char_to_move_in = (grep { ! $_->is_dead } $group_to_move_from->members)[0];
	   $self->{params}{character_id} = $char_to_move_in->id;
	   $self->{params}{to} = 'party';
	   
	   my $char_to_swap_out;
	   if ($test->{swap}) {
	       my $group_to_swap_from = $test->{swap_with_garrison} ? $garrison : $party;
	       $char_to_swap_out = ($group_to_swap_from->members)[0];
	       $self->{params}{swapped_char_id} = $char_to_swap_out->id;
	   }
	   
	   # WHEN
	   my $error;
	   try {
	       RPG::C::Garrison->character_move( $self->{c} );
	   }
	   catch {
	       $error = $_;
	   };
	   
	   # THEN
	   if ($test->{error_expected}) {
	       like($error, $test->{error_expected}, "Correct error message was received") or diag Dumper $self->{params};
	       next;
	   }
	   
	   is($error, undef, "No error, as expected");
	   
	   $char_to_move_in->discard_changes;
	   is($char_to_move_in->garrison_id, undef, "Garrison char was moved into party");
	   
	   if ($char_to_swap_out) {
	       $char_to_swap_out->discard_changes;
	       is($char_to_swap_out->garrison_id, $garrison->id, "Party char was swapped out of party");   
	   }
	   
	}    
}
1;