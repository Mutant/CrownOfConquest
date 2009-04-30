use strict;
use warnings;

package Test::RPG::C::Combat;

use base qw(Test::RPG);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Data::Dumper;

sub combat_startup : Test(startup=>1) {
	my $self = shift;
	
	$self->{dice} = Test::MockObject->fake_module( 
		'Games::Dice::Advanced',
		roll => sub { $self->{roll_result} || 0 }, 
	);
	
	# TODO: move into base class and possibly make a yml config?
	Test::MockObject->fake_module(
		'RPG',
		'config' => sub { {xp_multiplier=>10} },
	);
	
	use_ok 'RPG::C::Combat';
	
}

sub combat_shutdown : Test(shutdown) {
	my $self = shift;
	
	delete $INC{'Games/Dice/Advanced.pm'};
	require 'Games/Dice/Advanced.pm';
}

sub test_select_action : Tests(4) {
	my $self = shift;
	
	$self->{mock_forward}{'/panel/refresh'} = sub { };
	
	my $mock_char = Test::MockObject->new();	
	$mock_char->set_true('last_combat_action');
	$mock_char->set_true('update');
	
	my $mock_rs = Test::MockObject->new();
	$mock_rs->set_always('find', $mock_char);
	
	$self->{c}->set_always('model', $mock_rs);
	
	$self->{params}{action_param} = ['',''];
	$self->{params}{character_id} = 1;
	$self->{params}{action} = 'Attack';
	
	RPG::C::Combat->select_action($self->{c});
	
	is_deeply($self->{session}{combat_action_param}, {});
	
	$self->{params}{action_param} = ['foo','bar'];
	
	RPG::C::Combat->select_action($self->{c});
	
	is_deeply($self->{session}{combat_action_param}, {1 => ['foo','bar']});
	
	$self->{params}{action_param} = 'foo1';
	
	RPG::C::Combat->select_action($self->{c});
	
	is_deeply($self->{session}{combat_action_param}, {1 => 'foo1'});
	
	$self->{params}{action_param} = 'foo2';
	$self->{params}{character_id} = 2;
	
	RPG::C::Combat->select_action($self->{c});
	
	is_deeply($self->{session}{combat_action_param}, {1 => 'foo1', 2 => 'foo2'});
}

1;