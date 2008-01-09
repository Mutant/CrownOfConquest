package Test::RPG;

use strict;
use warnings;

use base qw(Test::Class);

sub setup_context : Test(setup) {
	my $self = shift;
	
	my $mock_context = Test::MockObject->new;
	
	$self->{c} = $mock_context;	
}

1;