use strict;
use warnings;

package Test::RPG::DB;

use base qw(Test::RPG);

use RPG::Schema;

sub db_startup : Test(startup) {
	my $self = shift;

	$self->{schema} = RPG::Schema->connect(
		{}, # TODO: pass in config
		"dbi:mysql:game-test",
        "root",
        "",
		{AutoCommit => 1},
	);	
}

sub setup_context : Test(setup) {
	my $self = shift;
	
	$self->SUPER::setup_context(@_);
	
	$self->{c}->mock( model => sub { $self->{schema}->resultset($_[1]) } );
}

1;