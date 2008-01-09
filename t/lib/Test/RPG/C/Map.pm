use strict;
use warnings;

package Test::RPG::C::Map;

use base qw(Test::RPG::DB);

use Test::MockObject;
use Test::More;

use RPG::C::Map;

use Data::Dumper;

sub test_auto : Tests(3) {
	my $self = shift;
	
	$self->{c}->set_always('session', {party_id => 1});
	
	my %stash;
	$self->{c}->set_always('stash',\%stash);
	
	is(RPG::C::Map->auto($self->{c}), 1, "Auto returned 1");
	
	my ($method, $args) = $self->{c}->next_call(3);
	
	is($method, 'stash', "Stash method called");
	isa_ok($stash{party}, "RPG::Schema::Party");	
}

1;