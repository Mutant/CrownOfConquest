use strict;
use warnings;

package Test::RPG::Schema::Quest;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

sub startup : Tests(startup=>1) {
	use_ok('RPG::Schema::Quest');
}

sub setup_data : Tests(setup) {
	my $self = shift;
	
	$self->{schema}->storage->dbh->begin_work;

	$self->{quest_type} = $self->{schema}->resultset('Quest_Type')->create(
		{
			quest_type => 'kill_creatures_near_town',	
		}
	);
	
	$self->{quest_param_name_1} = $self->{schema}->resultset('Quest_Param_Name')->create(
		{
			quest_param_name => 'Number Of Creatures To Kill',
			quest_type_id => $self->{quest_type}->id,
		}
	);

	$self->{quest_param_name_2} = $self->{schema}->resultset('Quest_Param_Name')->create(
		{
			quest_param_name => 'Range',
			quest_type_id => $self->{quest_type}->id,
		}
	);
	
	$self->{config} = {
		quest_type_vars => {
			kill_creatures_near_town => {
				min_cgs_to_kill => 2,
				max_cgs_to_kill => 2,
				range => 3,
			},			
		},
	};		
}

sub delete_data : Tests(teardown) {
	my $self = shift;
	
	$self->{schema}->storage->dbh->rollback;
}

sub test_create_quest : Tests(7) {
	my $self = shift;
	
	my $quest = $self->{schema}->resultset('Quest')->create(
		{
			quest_type_id => $self->{quest_type}->id,
			town_id => 1,
		},
	);
	
	isa_ok($quest, 'RPG::Schema::Quest::Kill_Creatures_Near_Town', "Quest created with correct class");
	
	$quest = $self->{schema}->resultset('Quest')->find( $quest->id );
	
	isa_ok($quest, 'RPG::Schema::Quest::Kill_Creatures_Near_Town', "queried Quest with correct class");
	
	my @quest_params = $quest->quest_params;
	is(scalar @quest_params, 2, "2 Quest params created");
	
	my %quest_params_by_name = $quest->quest_params_by_name;
	is($quest->param_start_value('Number Of Creatures To Kill'), 2, "Number of creatures to kill start value set correctly");
	is($quest->param_current_value('Number Of Creatures To Kill'), 2, "Number of creatures to kill current value set correctly");
	is($quest->param_current_value('Range'), 3, "Range start value set correctly");
	is($quest->param_start_value('Range'), 3, "Range current value set correctly");
}

1;