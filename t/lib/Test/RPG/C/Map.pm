use strict;
use warnings;

package Test::RPG::M::Map;

use base qw(Test::Class);

use Test::MockObject;
use RPG::C::Map;

sub setup_context : Test(setup) {
	my $self = shift;
	
	my $mock_context = Test::MockObject->new;
	
	$self->{c} = $mock_context;
	
	#$mock_context->mock('stash');
}

sub test_begin : Tests {
	my $self = shift;
	
	$self->{c}->mock('session_id', {party_id => 1});
	
	RPG::C::Map->begin($self->{c});
	
	my ($method, $args) = $self->{c}->next_call;
	
	is($method, 'stash', "Stash method called");
	isa_ok($args->[0], '');	
}

1;