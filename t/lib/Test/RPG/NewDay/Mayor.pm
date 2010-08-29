use strict;
use warnings;

package Test::RPG::NewDay::Mayor;

use base qw(Test::RPG::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use DateTime;

use Test::MockObject::Extends;
use Test::More;

use Test::RPG::Builder::Town;
use Test::RPG::Builder::Day;
use Test::RPG::Builder::Character;

sub setup : Test(setup) {
    my $self = shift;

    $self->setup_context;
}

sub startup : Test(startup => 1) {
	my $self = shift;
	
	use_ok('RPG::NewDay::Action::Mayor');
	
	$self->mock_dice;	
	
} 

sub shutdown : Test(shutdown) {
	my $self = shift;
	
	undef $self->{roll_result};
	$self->unmock_dice;	
}

sub test_process_revolt_overthrow : Tests(4) {
	my $self = shift;
	
	# GIVEN
	$self->{roll_result} = 20;
	
	my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, );
	$town->peasant_state('revolt');
	$town->update;	
	
	my $character = Test::RPG::Builder::Character->build_character($self->{schema});
	$character->mayor_of($town->id);
	$character->update;
	
	my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );
	
	# WHEN
	$action->process_revolt($town);
	
	# THEN
	$character->discard_changes;
	is($character->mayor_of, undef, "Character no longer mayor of town");
	
	$town->discard_changes;
	is($town->peasant_state, undef, "Peasants no longer in revolt");
	is($town->mayor_rating, 0, "Mayor approval reset");
	
	my $new_mayor = $self->{schema}->resultset('Character')->find(
		{
			mayor_of => $town->id,
		}
	);
	is(defined $new_mayor, 1, "New mayor generated");
}

sub test_check_for_pending_mayor_expiry : Tests(2) {
	my $self = shift;
	
	# GIVEN
	my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, );
	$town->pending_mayor(1);
	$town->pending_mayor_date(DateTime->now()->subtract( hours => 24, seconds => 10 ));
	$town->update;
	
	my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );
	
	# WHEN
	$action->check_for_pending_mayor_expiry($town);
	
	# THEN
	$town->discard_changes;
	is($town->pending_mayor, undef, "Pending mayor cleared");
	is($town->pending_mayor_date, undef, "Pending mayor date cleared");

}

1;