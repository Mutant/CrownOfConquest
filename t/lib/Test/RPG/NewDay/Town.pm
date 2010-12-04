use strict;
use warnings;

package Test::RPG::NewDay::Town;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Town;
use Test::RPG::Builder::Day;
use Test::RPG::Builder::Land;
use Test::RPG::Builder::Party;

use Data::Dumper;
use DateTime;

sub startup : Test(startup => 1) {
    my $self = shift;

    use_ok 'RPG::NewDay::Action::Town';
    
    $self->mock_dice;

}

sub setup : Test(setup) {
    my $self = shift;

    my $day = Test::RPG::Builder::Day->build_day( $self->{schema}, turns_used => 1000 );

    my $mock_context = Test::MockObject->new();
    $mock_context->set_always( 'schema',    $self->{schema} );
    $mock_context->set_always( 'config',    $self->{config} );
    $mock_context->set_always( 'yesterday', $day );
    $mock_context->set_always( 'logger',    $self->{mock_logger} );
    $mock_context->set_isa('RPG::NewDay::Context');

    $self->{mock_context} = $mock_context;
    
    $self->{rolls} = undef;
    $self->{roll_result} = undef;
}

sub shutdown : Test(shutdown) {
	my $self = shift;
	
	$self->unmock_dice;	
}

sub test_calculate_prosperity : Tests(1) {
    my $self = shift;

    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );

    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, land_id => $land[4]->id );

    $self->{schema}->resultset('Party_Town')->create(
        {
            party_id              => 1,
            town_id               => $town->id,
            tax_amount_paid_today => 10,
        }
    );

    $self->{schema}->resultset('Party_Town')->create(
        {
            party_id              => 2,
            town_id               => $town->id,
            tax_amount_paid_today => 20,
        }
    );

    $self->{config}->{prosperity_calc_ctr_range} = 3;
    $self->{config}->{max_prosp_change}          = 5;

    my $town_action = RPG::NewDay::Action::Town->new( context => $self->{mock_context} );

    # WHEN
    $town_action->calculate_prosperity($town, 0);

    # THEN
    $town->discard_changes;
    is( $town->prosperity, 50, "Town prosperity increased correctly" );
}

sub test_get_prosperty_percentages : Tests(10) {
    my $self = shift;

    # GIVEN
    my @towns;
    my @prosp = ( 1, 5, 10, 15, 19, 30, 34, 40, 44, 55, 66, 77, 88, 90, 100 );

    foreach my $prosp (@prosp) {
        push @towns, Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => $prosp, );
    }

    my $town_action = RPG::NewDay::Action::Town->new( context => $self->{mock_context} );

    # WHEN
    my %actual_prosp = $town_action->_get_prosperity_percentages(@towns);

    # THEN
    is( $actual_prosp{0},  13,    "Percent correct for 0 - 9" );
    is( $actual_prosp{10}, 20,    "Percent correct for 10 - 19" );
    is( $actual_prosp{20}, undef, "Percent correct for 20 - 29" );
    is( $actual_prosp{30}, 13,    "Percent correct for 30 - 39" );
    is( $actual_prosp{40}, 13,    "Percent correct for 40 - 49" );
    is( $actual_prosp{50}, 7,     "Percent correct for 50 - 59" );
    is( $actual_prosp{60}, 7,     "Percent correct for 60 - 69" );
    is( $actual_prosp{70}, 7,     "Percent correct for 70 - 79" );
    is( $actual_prosp{80}, 7,     "Percent correct for 80 - 89" );
    is( $actual_prosp{90}, 13,    "Percent correct for 90 - 100" );
}

sub test_calculate_changes_needed : Tests(10) {
    my $self = shift;

    # GIVEN
    my %target_prosp = (
        90 => 4,
        80 => 6,
        70 => 8,
        60 => 8,
        50 => 10,
        40 => 14,
        30 => 14,
        20 => 13,
        10 => 13,
        0  => 10,
    );

    my %actual_prosp = (
        90 => 2,
        80 => 3,
        70 => 8,
        60 => 8,
        50 => 13,
        40 => 16,
        30 => 14,
        20 => 5,
        10 => 13,
        0  => 10,
    );

    my $town_count = 100;

    my $town_action = RPG::NewDay::Action::Town->new( context => $self->{mock_context} );

    # WHEN
    my %changes_needed = $town_action->_calculate_changes_needed( \%target_prosp, \%actual_prosp, $town_count );

    # THEN
    is( $changes_needed{90}, undef, "No changes needed for 90" );
    is( $changes_needed{80}, 3,     "3 more needed for 80" );
    is( $changes_needed{70}, undef, "No changes needed for 70" );
    is( $changes_needed{60}, undef, "No changes needed for 60" );
    is( $changes_needed{50}, -3,    "3 less needed for 50" );
    is( $changes_needed{40}, undef, "No changes needed for 40" );
    is( $changes_needed{30}, undef, "No changes needed for 30" );
    is( $changes_needed{20}, 8,     "8 more needed for 20" );
    is( $changes_needed{10}, undef, "No changes needed for 10" );
    is( $changes_needed{0},  undef, "No changes needed for 00" );
}

sub test_make_scaling_changes_pushes_town_down_with_smallest_adjustment : Tests(4) {
	my $self = shift;
	
	# GIVEN
	my @towns_to_create = (
		{
			current => 100, 
			adjustment => 5,
		},
		{
			current => 100, 
			adjustment => -5,
		},		
		{
			current => 100, 
			adjustment => 0,
		},
	);
	
	my @towns;
	my %prosp_changes;
	
    foreach my $town_rec (@towns_to_create) {
        my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => $town_rec->{current}, );
        $prosp_changes{$town->id} = {
        	prosp_change => $town_rec->{adjustment},
        };
        push @towns, $town;
    }
    
    my $town_action = RPG::NewDay::Action::Town->new( context => $self->{mock_context} );
    
    $self->{roll_result} = 2;
    
    # WHEN
    $town_action->_make_scaling_changes(90, -1, \%prosp_changes, @towns);
    
    # THEN
    $towns[0]->discard_changes;
    is($towns[0]->prosperity, 100, "Town with large positive adjustment not scaled");

    $towns[1]->discard_changes;
    is($towns[1]->prosperity, 100, "Town with large negative adjustment not scaled");

    $towns[2]->discard_changes;
    is($towns[2]->prosperity, 88, "Town with no adjustment is scaled");
    
    is($prosp_changes{$towns[2]->id}{prosp_change}, -12, "Prosperity change recorded");
}

sub test_make_scaling_changes_pulls_towns_up_with_smallest_adjustment : Tests(8) {
	my $self = shift;
	
	# GIVEN
	my @towns_to_create = (
		{
			current => 100, 
			adjustment => 5,
		},
		{
			current => 90, 
			adjustment => 0,
		},		
		{
			current => 85, 
			adjustment => 5,
		},
		{
			current => 85, 
			adjustment => 2,
		},
		{
			current => 84, 
			adjustment => 0,
		},
		{
			current => 89, 
			adjustment => 5,
		},
	);
	
	my @towns;
	my %prosp_changes;
	
    foreach my $town_rec (@towns_to_create) {
        my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => $town_rec->{current}, );
        $prosp_changes{$town->id} = {
        	prosp_change => $town_rec->{adjustment},
        };
        push @towns, $town;
    }
    
    my $town_action = RPG::NewDay::Action::Town->new( context => $self->{mock_context} );
    
    $self->{roll_result} = 2;
    
    # WHEN
    $town_action->_make_scaling_changes(90, 2, \%prosp_changes, @towns);
    
    # THEN
    $towns[0]->discard_changes;
    is($towns[0]->prosperity, 100, "First town not in category to move left alone");

    $towns[1]->discard_changes;
    is($towns[1]->prosperity, 90, "Second town with large negative adjustment not scaled");

    $towns[2]->discard_changes;
    is($towns[2]->prosperity, 85, "Town with largest adjustment in category not scaled");

    $towns[3]->discard_changes;
    is($towns[3]->prosperity, 91, "Town with second smallest adjustment scaled");

    $towns[4]->discard_changes;
    is($towns[4]->prosperity, 91, "Town with smallest adjustment scaled");

    $towns[5]->discard_changes;
    is($towns[5]->prosperity, 89, "Town with highest prosperity but large adjustment left alone");

    is($prosp_changes{$towns[3]->id}{prosp_change}, 8, "Prosperity change for first move recorded");
    is($prosp_changes{$towns[4]->id}{prosp_change}, 7, "Prosperity change for second move recorded");
}

sub test_make_scaling_changes_pushes_lower_props_towns_first : Tests(3) {
	my $self = shift;
	
	# GIVEN
	my @towns_to_create = (
		{
			current => 91, 
			adjustment => 5,
		},
		{
			current => 90, 
			adjustment => 5,
		},
	);
	
	my @towns;
	my %prosp_changes;
	
    foreach my $town_rec (@towns_to_create) {
        my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => $town_rec->{current}, );
        $prosp_changes{$town->id} = {
        	prosp_change => $town_rec->{adjustment},
        };
        push @towns, $town;
    }
    
    my $town_action = RPG::NewDay::Action::Town->new( context => $self->{mock_context} );
    
    $self->{roll_result} = 2;
    
    # WHEN
    $town_action->_make_scaling_changes(90, -1, \%prosp_changes, @towns);
    
    # THEN
    $towns[0]->discard_changes;
    is($towns[0]->prosperity, 91, "Town with higher prosp not scaled");

    $towns[1]->discard_changes;
    is($towns[1]->prosperity, 88, "Town with lower prosp scaled");

    is($prosp_changes{$towns[1]->id}{prosp_change}, 3, "Prosperity change for move recorded");
}

sub test_make_scaling_changes_pulls_higher_prosp_towns_first : Tests(6) {
	my $self = shift;
	
	# GIVEN
	my @towns_to_create = (
		{
			current => 47, 
			adjustment => 5,
		},		
		{
			current => 48, 
			adjustment => 5,
		},
		{
			current => 49, 
			adjustment => 8,
		},
		{
			current => 49, 
			adjustment => 5,
		},
	);
	
	my @towns;
	my %prosp_changes;
	
    foreach my $town_rec (@towns_to_create) {
        my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => $town_rec->{current}, );
        $prosp_changes{$town->id} = {
        	prosp_change => $town_rec->{adjustment},
        };
        push @towns, $town;
    }
    
    my $town_action = RPG::NewDay::Action::Town->new( context => $self->{mock_context} );
    
    $self->{roll_result} = 2;
    
    # WHEN
    $town_action->_make_scaling_changes(50, 2, \%prosp_changes, @towns);
    
    # THEN
    $towns[0]->discard_changes;
    is($towns[0]->prosperity, 47, "Lower prosp town not scaled");

    $towns[1]->discard_changes;
    is($towns[1]->prosperity, 51, "Town with lower prosp and adjustment scaled");

    $towns[2]->discard_changes;
    is($towns[2]->prosperity, 49, "Town with high prosp and high adjustment not scaled");

    $towns[3]->discard_changes;
    is($towns[3]->prosperity, 51, "Town with high prosp and low adjustment scaled");

    is($prosp_changes{$towns[1]->id}{prosp_change}, 8, "Prosperity change for first move recorded");
    is($prosp_changes{$towns[3]->id}{prosp_change}, 7, "Prosperity change for second move recorded");
}


sub test_update_prestige : Tests(4) {
    my $self = shift;
    
    # GIVEN
    my $party1 = Test::RPG::Builder::Party->build_party($self->{schema});
    my $party2 = Test::RPG::Builder::Party->build_party($self->{schema}, defunct => DateTime->now());
    
    my $town1= Test::RPG::Builder::Town->build_town($self->{schema});
    my $town2= Test::RPG::Builder::Town->build_town($self->{schema});
    my $town3= Test::RPG::Builder::Town->build_town($self->{schema});
    
    my $party_town1 = $self->{schema}->resultset('Party_Town')->create(
        {
            party_id => $party1->id,
            town_id => $town1->id,
            prestige => 0,
        }
    );

    my $party_town2 = $self->{schema}->resultset('Party_Town')->create(
        {
            party_id => $party1->id,
            town_id => $town2->id,
            prestige => 2,
        }
    );

    my $party_town3 = $self->{schema}->resultset('Party_Town')->create(
        {
            party_id => $party1->id,
            town_id => $town3->id,
            prestige => -2,
        }
    );

    my $party_town4 = $self->{schema}->resultset('Party_Town')->create(
        {
            party_id => $party2->id,
            town_id => $town3->id,
            prestige => -2,
        }
    );
    
    $self->{roll_result} = 1;
    
    my $town_action = RPG::NewDay::Action::Town->new( context => $self->{mock_context} );
    
    # WHEN
    $town_action->update_prestige();
    
    # THEN
    $party_town1->discard_changes;
    is($party_town1->prestige, 0, "Prestige unchanged");
    
    $party_town2->discard_changes;
    is($party_town2->prestige, 1, "Prestige reduced");    

    $party_town3->discard_changes;
    is($party_town3->prestige, -1, "Prestige increased");

    $party_town4->discard_changes;
    is($party_town4->prestige, -2, "Prestige unchanged (party defunct)");

}

sub test_set_discount : Test(3) {
    my $self = shift;
    
    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, );
    
    $self->{config}{discount_types} = ['sage','healer','blacksmith'];
    $self->{config}{max_discount_value} = 30;
    $self->{config}{min_discount_value} = 10;
    
    my $town_action = RPG::NewDay::Action::Town->new( context => $self->{mock_context} );
    
    $self->{rolls} = [25,5,1];
    
    # WHEN
    $town_action->set_discount($town);
    
    # THEN
    $town->discard_changes;
    is(grep({$_ eq $town->discount_type} ('sage','healer','blacksmith')), 1, "Discount type set correctly");
    is($town->discount_value, 30, "Discount value set correctly");
    is($town->discount_threshold, 75, "Discount threshold set correectly");
}

sub test_set_discount_doesnt_use_blacksmith_type_if_no_blacksmith : Test(3) {
    my $self = shift;
    
    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, );
    
    # TODO: need to mock out shuffle, currently test will give false positives 50% of the time
    $self->{config}{discount_types} = ['healer','blacksmith'];
    $self->{config}{max_discount_value} = 30;
    $self->{config}{min_discount_value} = 10;
    
    my $town_action = RPG::NewDay::Action::Town->new( context => $self->{mock_context} );
    
    $self->{rolls} = [25,5,1];
    
    # WHEN
    $town_action->set_discount($town);
    
    # THEN
    $town->discard_changes;
    is($town->discount_type, 'healer', "Discount type set correctly");
    is($town->discount_value, 30, "Discount value set correctly");
    is($town->discount_threshold, 75, "Discount threshold set correectly");
}

sub test_decay_ctr : Test(9) {
	my $self = shift;
	
	# GIVEN	
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    
    $land[8]->creature_threat(60);
    $land[8]->update;

    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, land_id => $land[4]->id );    
    
    $self->{rolls} = [1, 1, 40, 5, 1, 50, 1, 1, 1, 50, 1];
    
    $self->{config}{decay_ctr_range} = 1;   
    
    my $town_action = RPG::NewDay::Action::Town->new( context => $self->{mock_context} );
    
    # WHEN
    $town_action->decay_ctr($town);
    
    # THEN
    my @expected_ctr = (10, 10, 5, 10, 10, 9, 10, 10, 60);
    
    for my $i (0..$#land) {
    	$land[$i]->discard_changes;
    	is($land[$i]->creature_threat, $expected_ctr[$i], "Correct ctr for " . $land[$i]->x . ', ' . $land[$i]->y);   		
    }
	
}

1;
