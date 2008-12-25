use strict;
use warnings;

package Test::RPG::C::Combat;

use base qw(Test::RPG);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Data::Dumper;

sub startup : Test(startup=>1) {
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

sub shutdown : Test(shutdown) {
	my $self = shift;
	
	delete $INC{'Games/Dice/Advanced.pm'};	
}

sub test_finish : Tests(18) {
	my $self = shift;
	
	my @creatures;
	for (1..5) {
		my $mock_creature_type = Test::MockObject->new();
		$mock_creature_type->set_always('level', 1);
		my $mock_creature = Test::MockObject->new();
		$mock_creature->set_always('type', $mock_creature_type);
		push @creatures, $mock_creature;
	}
	my $mock_cg = Test::MockObject->new();
	$mock_cg->set_bound('creatures', \@creatures);
	$mock_cg->set_true('land_id');
	$mock_cg->set_true('update');
	$mock_cg->set_always('level', 1);

	my @characters;
	for (1..5) {
		my $mock_character = Test::MockObject->new();
		$mock_character->set_always('id', $_);
		$mock_character->set_always('character_name', "char$_");
		$mock_character->set_always('xp', 50);
		$mock_character->set_true('update');
		$mock_character->mock('character_effects', sub {return ()});
		$mock_character->set_false('is_dead');
		push @characters, $mock_character;
	}
	my $mock_party = Test::MockObject->new();
	$mock_party->set_bound('characters', \@characters);
	$mock_party->set_always('gold', 100);
	$mock_party->set_true('update');
	$mock_party->set_true('in_combat_with');
	
	my $mock_party_location = Test::MockObject->new();
	$mock_party_location->set_always('creature_threat', 5);
	$mock_party_location->set_always('update');
	
	my $mock_combat_log = Test::MockObject->new();
	$mock_combat_log->set_true('gold_found');
	$mock_combat_log->set_true('xp_awarded');
	$mock_combat_log->set_true('encounter_ended');
	
	$self->{stash} = {
		creature_group => $mock_cg,
		party => $mock_party,
		party_location => $mock_party_location,
		combat_log => $mock_combat_log,
	};	
	
	$self->{roll_result} = 5;
		
	$self->{mock_forward}{'/combat/distribute_xp'} = sub { {1 => 10, 2 => 10, 3 => 8, 4 => 10, 5 => 14} };
	$self->{mock_forward}{'check_for_item_found'} = sub { };
	$self->{mock_forward}{'RPG::V::TT'} = sub { };
	$self->{mock_forward}{'/quest/check_action'} = sub { [] };	
	$self->{mock_forward}{'/party/xp_gain'} = sub { ['xp_messages'] };
	$self->{mock_forward}{'end_of_combat_cleanup'} = sub { };	
	
	RPG::C::Combat->finish($self->{c});
	
	my $char_msgs;
	foreach my $message (@{$self->{c}->stash->{combat_messages}}) {
		if ($message eq 'xp_messages') {
			ok(1, "xp messages put into combat messages");
		}
		else {
			like($message, qr/ 25 gold/, "gold found message created"); 
		}
	}	
	my @args;
	
	is($mock_party->call_pos(2), 'in_combat_with', "in_combat_with set to new value");
	@args = $mock_party->call_args(2);
	is($args[1], undef, "No longer in combat");	
	
	is($mock_party->call_pos(4), 'gold', "Gold set to new value");
	@args = $mock_party->call_args(4);
	is($args[1], 125, "Gold set to correct value");
	
	$mock_party->called_ok('update', 'Party updated');
	
	is($mock_cg->call_pos(3), 'land_id', 'Creature group land id changed');
	is($mock_cg->call_pos(4), 'update', 'Creature group updated');
	
	is($mock_party_location->call_pos(2), 'creature_threat', "Create threat modified");
	@args = $mock_party_location->call_args(2);	
	is($args[1], 0, "Reduced by 5");
	
	$mock_party_location->called_ok('update', "Location updated");

}

sub test_distribute_xp : Tests(12) {
	my $self = shift;
	
	my @tests = (
		{
			xp => 100,
			characters => {
				'1' => {
					damage_done => 10,
					attack_count => 5,
				},
				'2' => {
					damage_done => 10,
					attack_count => 5,
				},
			},
			result => {
				1 => 50,
				2 => 50,	
			},
			description => 'Two chars, take 50% each',
		},
	
		{
			xp => 100,
			characters => {
				'1' => {
					damage_done => 10,
					attack_count => 5,
				},
				'2' => {
					damage_done => 10,
					attack_count => 5,
				},
				'3' => {
					damage_done => 10,
					attack_count => 5,
				},	
				'4' => {
					damage_done => 0,
					attack_count => 0,
				},	
				'5' => {
					damage_done => 0,
					attack_count => 0,
				},											
			},
			result => {
				1 => 26,
				2 => 26,
				3 => 26,
				4 => 10,
				5 => 10,	
			},
			description => 'Two chars take minimum, three chars, take 30% each',
		},
		
		{
			xp => 100,
			characters => {
				'1' => {
					damage_done => 75,
					attack_count => 0,
				},
				'2' => {
					damage_done => 0,
					attack_count => 75,
				},	
				'3' => {
					damage_done => 25,
					attack_count => 25,
				},															
			},
			result => {
				1 => 36,
				2 => 33,
				3 => 29,	
			},
			description => 'Three chars get different shares because of weighting between damange_done / attack_count',
		},				
		
		{
			xp => 103,
			characters => {
				'1' => {
					damage_done => 10,
					attack_count => 5,
				},
				'2' => {
					damage_done => 10,
					attack_count => 5,
				},
			},
			result => {
				1 => 51,
				2 => 51,	
			},
			description => 'Two chars, take 50% each, odd number of xp',
		},		
		
	);
	
	foreach my $test (@tests) {
		my @char_ids;
		my %damage;
		my %attacks;

		foreach my $char_id (keys %{$test->{characters}}) {
			push @char_ids, $char_id;
			$damage{$char_id}  = $test->{characters}{$char_id}{damage_done};
			$attacks{$char_id} = $test->{characters}{$char_id}{attack_count};
		}
		
		# Setup session		
		$self->{session} = {damage_done => \%damage, attack_count => \%attacks};
		
		my $dist_xp = RPG::C::Combat->distribute_xp($self->{c}, $test->{xp}, \@char_ids);
		#warn Dumper $dist_xp;
		#warn Dumper $test->{result};
		is_deeply($dist_xp, $test->{result}, $test->{description});
		
		is($self->{session}{damage_done},  undef, "Damage done cleared");
		is($self->{session}{attack_count}, undef, "Attack count cleared");
	}	
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