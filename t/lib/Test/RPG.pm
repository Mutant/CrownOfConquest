package Test::RPG;

use strict;
use warnings;

use base qw(Test::Class);

use Carp;

sub setup_context : Test(setup) {
	my $self = shift;
	
	my $mock_context = Test::MockObject->new;
	
	$self->{c} = $mock_context;
	
	$self->{c}->mock(
		'forward',
		sub {
			my $package = shift;
			my $path = shift;
			my $args = shift;
			
			my $sub = $self->{mock_forward}{$path};
			
			croak "Forward to $path called, but no mock sub defined" unless ref $sub eq 'CODE';
			
			return $sub->($args);
		}
	);
	
	my $req = Test::MockObject->new();
	$req->mock('param', sub { 
		my $ret = $self->{params}{$_[1]};
		
		if (ref $ret eq 'ARRAY' && wantarray) {
			return @$ret;
		}
		
		return $ret;
	} );
	$self->{c}->set_always('req', $req);

	$self->{stash} ||= {};
	$self->{c}->mock( 'stash', sub { $self->{stash} } );

	$self->{session} ||= {};
	$self->{c}->mock( 'session', sub { $self->{session} } );

	$self->{config} ||= {};
	$self->{c}->mock( 'config', sub { $self->{config} } );
	
	$self->{mock_response} = Test::MockObject->new;
	$self->{mock_response}->mock('body', sub {});
	$self->{c}->set_always('res',$self->{mock_response});
	
}

sub clear_data : Test(teardown) {
	my $self = shift;
	
	undef $self->{stash};
	undef $self->{session};
	undef $self->{config};
}



1;