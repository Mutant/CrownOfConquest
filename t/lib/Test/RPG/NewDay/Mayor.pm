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
use Test::RPG::Builder::Item;
use Test::RPG::Builder::Item_Type;

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

sub test_process_revolt_overthrow : Tests(7) {
	my $self = shift;
	
	# GIVEN
	$self->{roll_result} = 20;
	
	my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, );
	$town->peasant_state('revolt');
	$town->update;	
	
	my $character = Test::RPG::Builder::Character->build_character($self->{schema});
	$character->mayor_of($town->id);
	$character->update;
	
	my $garrison_character = Test::RPG::Builder::Character->build_character($self->{schema});
	$garrison_character->status('mayor_garrison');
	$garrison_character->status_context($town->id);
	$garrison_character->update;
	
	my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );
	
	$self->{config}{level_hit_points_max}{test_class} = 6;
	
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
	
	$garrison_character->discard_changes;
	is($garrison_character->status, 'morgue', "Garrison character placed in morgue");
	is($garrison_character->status_context, $town->id, "Garrsion character has correct status context");
	is($garrison_character->hit_points, 0, "Garrison character has 0 hps");
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

sub test_refresh_mayor : Tests(5) {
	my $self = shift;
	
	# GIVEN
	my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 5, max_hit_point => 10 );
	my $ammo_type = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema},
		variables => [{name => 'Quantity', create_on_insert => 1}],
	);
	my $ranged = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema},
		category_name => 'Ranged Weapon',
		attributes => [{item_attribute_name => 'Ammunition', item_attribute_value => $ammo_type->id}]
	);
	my $item = Test::RPG::Builder::Item->build_item($self->{schema}, 
		item_type_id => $ranged->id, 
		char_id => $character->id,
		variables => [{item_variable_name=>'Durability', item_variable_value => 10, max_value => 100}],		
	);	
	my $ammo = Test::RPG::Builder::Item->build_item($self->{schema}, 
		item_type_id => $ammo_type->id, 
		char_id => $character->id,
	);		
	$ammo->variable('Quantity', 10);
	
	my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );
	
	# WHEN
	$action->refresh_mayor($character);
	
	# THEN
	$character->discard_changes;
	is($character->hit_points, 10, "Mayor healed to full hit points");
	my @items = $character->items;
	is(scalar @items, 3, "Mayor now has 2 items");
	my ($new_ammo) = grep { $_->id != $item->id && $_->id != $ammo->id } @items;
	is($new_ammo->item_type_id, $ammo_type->id, "Ammo created with correct item type");
	is($new_ammo->variable('Quantity'), 200, "Quantity of ammo set correctly");
	
	$item->discard_changes;
	is($item->variable('Durability'), 100, "Weapon repaired");
}

sub test_generate_advice : Tests(2) {
	my $self = shift;
	
	# GIVEN
	my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, advisor_fee => 50, gold => 20 );
	
	my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );
	
	# WHEN
	$action->generate_advice($town);
	
	# THEN
	my $advice = $self->{schema}->resultset('Town_History')->find(
	   {
	       town_id => $town->id,
	       type => 'advice',
	   }
	);
	is(defined $advice, 1, "Advice generated");
	
	$town->discard_changes;
	is($town->gold, 0, "Town gold reduced");
}

1;