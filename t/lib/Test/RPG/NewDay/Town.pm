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

sub startup : Test(startup => 1) {
    my $self = shift;

    use_ok 'RPG::NewDay::Action::Town';

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
}

sub test_calculate_prosperity : Tests {
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
    $town_action->calculate_prosperity($town);

    # THEN
    $town->discard_changes;
    is( $town->prosperity, 53, "Town prosperity increased correctly" );
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
    my %actual_prosp = $town_action->_get_prosperty_percentages(@towns);

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

sub test_select_town_from_category : Tests(1) {
    my $self = shift;

    # GIVEN
    my @towns;
    my @prosp = ( 1, 5, 10, 15, 19, 30, 34, 40, 44, 55, 66, 77, 88, 90, 100 );

    foreach my $prosp (@prosp) {
        push @towns, Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => $prosp, );
    }

    my $town_action = RPG::NewDay::Action::Town->new( context => $self->{mock_context} );

    # WHEN
    my $town = $town_action->_select_town_from_category( 50, @towns );

    # THEN
    is( $town->prosperity, 55, "Selected correct town" );
}

sub test_select_town_from_category_zero_category : Tests(1) {
    my $self = shift;

    # GIVEN
    my @towns;
    my @prosp = ( 1, 10, 15, 19, 30, 34, 40, 44, 55, 66, 77, 88, 90, 100 );

    foreach my $prosp (@prosp) {
        push @towns, Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => $prosp, );
    }

    my $town_action = RPG::NewDay::Action::Town->new( context => $self->{mock_context} );

    # WHEN
    my $town = $town_action->_select_town_from_category( 0, @towns );

    # THEN
    is( $town->prosperity, 1, "Selected correct town" );
}

sub test_change_prosperity_as_needed : Tests(11) {
    my $self = shift;

    # GIVEN
    my @towns;
    my @prosp = ( 1, 5, 10, 30, 40, 55, 66, 77, 88, 90, 100 );

    foreach my $prosp (@prosp) {
        push @towns, Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => $prosp, );
    }

    my %actual_prosp = ( 40 => 1, );

    my %changes_needed = (
        50 => 1,
        30 => -1,
        20 => 1,
        80 => -1,
    );

    my $town_action = RPG::NewDay::Action::Town->new( context => $self->{mock_context} );

    # WHEN
    $town_action->_change_prosperity_as_needed( \%actual_prosp, \@towns, %changes_needed );

    # THEN
    map { $_->discard_changes } @towns;
    is( $towns[0]->prosperity,  1,   "Prosperity unchanged" );
    is( $towns[1]->prosperity,  5,   "Prosperity unchanged" );
    is( $towns[2]->prosperity,  10,  "Prosperity unchanged" );
    is( $towns[3]->prosperity,  27,  "Prosperity reduced" );
    is( $towns[4]->prosperity,  43,  "Prosperity increased" );
    is( $towns[5]->prosperity,  55,  "Prosperity unchanged" );
    is( $towns[6]->prosperity,  66,  "Prosperity unchanged" );
    is( $towns[7]->prosperity,  77,  "Prosperity unchanged" );
    is( $towns[8]->prosperity,  91,  "Prosperity increase" );
    is( $towns[9]->prosperity,  90,  "Prosperity unchanged" );
    is( $towns[10]->prosperity, 100, "Prosperity unchanged" );
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

1;
