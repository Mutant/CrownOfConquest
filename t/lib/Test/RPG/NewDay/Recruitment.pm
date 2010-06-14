use strict;
use warnings;

package Test::RPG::NewDay::Recruitment;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

sub startup : Test(startup => 1) {
    my $self = shift;

    use_ok 'RPG::NewDay::Action::Recruitment';
   
}

sub test_calculate_xp_max_level : Tests(2) {
	my $self = shift;
	# GIVEN
	my %levels = (
		1 => 0,
		2 => 30,
	);

    $self->mock_dice;
    $self->{roll_result} = 20;
	
	# WHEN
	my $result = RPG::NewDay::Action::Recruitment->_calculate_xp(2, 2, %levels);
	
	# THEN
	is($self->{mock_dice_params}->[1], '1d30', "Correct dice roll");
	is($result, 50, "Result correct");
	
	$self->unmock_dice;
}

sub test_calculate_xp_level_1 : Tests(2) {
	my $self = shift;
	# GIVEN
	my %levels = (
		1 => 0,
		2 => 10,
		3 => 30,
	);

    $self->mock_dice;
    $self->{roll_result} = 5;
	
	# WHEN
	my $result = RPG::NewDay::Action::Recruitment->_calculate_xp(1, 3, %levels);
	
	# THEN
	is($self->{mock_dice_params}->[1], '1d10', "Correct dice roll");
	is($result, 5, "Result correct");
	
	$self->unmock_dice;
}