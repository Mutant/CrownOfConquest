package Test::RPG;

use strict;
use warnings;

use base qw(Test::Class);

use Carp;
use Data::Dumper;

sub aa_init_params : Test(startup) {
    my $self = shift;
    
    $self->{config} = {};
}

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
	$req->mock('params', sub {$self->{params}});
	$self->{c}->set_always('req', $req);

	$self->{stash} ||= {};
	$self->{c}->mock( 'stash', sub { $self->{stash} } );

	$self->{session} ||= {};
	$self->{c}->mock( 'session', sub { $self->{session} } );

	$self->{config} ||= {};
	$self->{c}->mock( 'config', sub { $self->{config} } );
	
	$self->{mock_response} = Test::MockObject->new;
	$self->{mock_response}->mock('body', sub {});
	$self->{mock_response}->set_true('redirect');
	$self->{c}->set_always('res',$self->{mock_response});
	
	$self->{mock_logger} = Test::MockObject->new();
	$self->{mock_logger}->set_true('debug');
	$self->{mock_logger}->set_true('info');
	$self->{mock_logger}->set_isa('Log::Dispatch');
	$self->{c}->set_always('log',$self->{mock_logger});
	
	
		
}

sub clear_data : Test(teardown) {
	my $self = shift;
	
	undef $self->{stash};
	undef $self->{session};
	undef $self->{config};
	undef $self->{params};
}

sub clear_dice_data : Tests(shutdown) {
    my $self = shift;

    # These could probably go in teardown, but some tests (wrongly) rely on them persisting
	undef $self->{counter};
	undef $self->{rolls};
	undef $self->{roll_result};

    no warnings;	
    delete $INC{'Games/Dice/Advanced.pm'};
    require 'Games/Dice/Advanced.pm';
    $INC{'Games/Dice/Advanced.pm'} = 1;
}


# Convenience method to Mock Games::Dice::Advanced
sub mock_dice {
    my $self = shift;   

    my $dice = Test::MockObject->new();

    $dice->fake_module(
        'Games::Dice::Advanced',
        roll => sub {
            $self->{counter} ||= 0;
            if ( $self->{rolls} ) {
                my $ret = $self->{rolls}[ $self->{counter} ];
                $self->{counter}++;
                return $ret;
            }
            else {
                return $self->{roll_result} || 0;
            }
        }
    );
    
    return $dice;

}



1;