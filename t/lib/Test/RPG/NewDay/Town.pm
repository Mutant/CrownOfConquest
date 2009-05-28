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

    my $day = Test::RPG::Builder::Day->build_day( $self->{schema}, turns_used => 1000 );

    my $mock_context = Test::MockObject->new();
    $mock_context->set_always( 'schema',    $self->{schema} );
    $mock_context->set_always( 'config',    $self->{config} );
    $mock_context->set_always( 'yesterday', $day );
    $mock_context->set_always( 'logger',    $self->{mock_logger} );
    $mock_context->set_isa('RPG::NewDay::Context');

    my $town_action = RPG::NewDay::Action::Town->new( context => $mock_context );

    # WHEN
    $town_action->calculate_prosperity($town);

    # THEN
    $town->discard_changes;
    is( $town->prosperity, 53, "Town prosperity increased correctly" );
}

1;
