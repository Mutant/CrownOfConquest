use strict;
use warnings;

package Test::RPG::DB;

use base qw(Test::RPG);

use RPG::Schema;

use Test::MockObject::Extends;

sub db_startup : Test(startup) {
	my $self = shift;
	
	return if $ENV{TEST_NO_DB};

	my $schema = RPG::Schema->connect(
		$self->{config},
		"dbi:mysql:game-test",
        "root",
        "root",
		{AutoCommit => 1},
	);	
	
	# Wrap in T::M::E so we can mock the config
	$schema = Test::MockObject::Extends->new( $schema );
	$schema->fake_module('RPG::Schema',
		'config' => sub { $self->{config} }
	);

	$self->{schema} = $schema;
}

sub setup_context : Test(setup) {
	my $self = shift;
	
	$self->SUPER::setup_context(@_);
	
	$self->{c}->mock( model => sub { $self->{schema}->resultset($_[1]) } );
}

1;