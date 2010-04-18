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

sub aa_setup_context : Test(setup) {
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
			
			# If there's no sub defined, warn and return (could still break the test, but let's be nice...)
			unless (ref $sub eq 'CODE') {
				warn "WARNING: Forward to $path called, but no mock sub defined\n";
				return;
			}; 
			
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
	$req->set_always('uri', $req);
	$req->set_always('path', $self->{request_path});
	$self->{c}->set_always('req',$req);		
	
	$self->{c}->set_always('req', $req);

	$self->{stash} ||= {};
	$self->{c}->mock( 'stash', sub { $self->{stash} } );

	$self->{session} ||= {};
	$self->{c}->mock( 'session', sub { $self->{session} } );

	$self->{config} ||= {};
	$self->{c}->mock( 'config', sub { $self->{config} } );
	
	$self->{flash} ||= {};
	$self->{c}->mock( 'flash', sub { $self->{flash} } );	
	
	$self->{mock_response} = Test::MockObject->new;
	$self->{mock_response}->mock('body', sub {});
	$self->{mock_response}->set_true('redirect');
	$self->{c}->set_always('res',$self->{mock_response});
	
	$self->{mock_logger} = Test::MockObject->new();
	$self->{mock_logger}->set_true('debug');
	$self->{mock_logger}->set_true('info');
	$self->{mock_logger}->mock('warning', sub { warn $_[1] });
	$self->{mock_logger}->set_isa('Log::Dispatch');
	$self->{c}->set_always('log',$self->{mock_logger});
	
    $self->{mock_forward}->{'RPG::V::TT'} = sub { $self->{template_args} = \@_ };
    
    $self->{mock_stats} = Test::MockObject->new();
    $self->{mock_stats}->set_true('profile');
    $self->{c}->set_always('stats',$self->{mock_stats});
	
	
		
}

sub clear_data : Test(teardown) {
	my $self = shift;
	
	undef $self->{stash};
	undef $self->{session};
	undef $self->{config};
	undef $self->{params};
    undef $self->{counter};
}

sub clear_dice_data : Tests(shutdown) {
    my $self = shift;

    # These could probably go in teardown, but some tests (wrongly) rely on them persisting
	undef $self->{rolls};
	undef $self->{roll_result};

=comment
    no warnings;	
    delete $INC{'Games/Dice/Advanced.pm'};
  
    require 'Games/Dice/Advanced.pm';
    $INC{'Games/Dice/Advanced.pm'} = 1;
=cut    
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

# Returns any template params that have been captured as a hashref
sub template_params {
    my $self = shift;
    
    return $self->{template_args}[0][0]{params};   
}


1;