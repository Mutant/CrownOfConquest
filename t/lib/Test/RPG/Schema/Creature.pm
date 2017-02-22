package Test::RPG::Schema::Creature;

use strict;
use warnings;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use RPG::Schema::Creature;

sub test_number_of_attacks : Tests(6) {
    my $self = shift;

    my $mock_creature = Test::MockObject->new();
    $mock_creature->set_always( 'effect_value', -0.5 );

    is(
        RPG::Schema::Creature::number_of_attacks( $mock_creature, ( 1, 1 ) ),
        0,
        'Not allowed to attack if attacked in recent rounds',
    );

    is(
        RPG::Schema::Creature::number_of_attacks( $mock_creature, ( 0, 0 ) ),
        1,
        'Allowed to attack if not attacked in recent rounds',
    );

    is(
        RPG::Schema::Creature::number_of_attacks($mock_creature),
        0,
        'Not allowed to attack if no history',
    );

    is(
        RPG::Schema::Creature::number_of_attacks( $mock_creature, ( 0, 1 ) ),
        0,
        'Not allowed to attack if attacked in recent rounds',
    );

    $mock_creature->set_always( 'effect_value', 0.5 );

    is(
        RPG::Schema::Creature::number_of_attacks( $mock_creature, ( 1, 1 ) ),
        2,
        'Two attacks allowed because of history',
    );

    $mock_creature->set_always( 'effect_value', 0 );

    is(
        RPG::Schema::Creature::number_of_attacks( $mock_creature, ( 0, 0, 0, 0, 0 ) ),
        1,
        'One attack allowed due to history',
    );

}

sub test_calculate_factor : Tests(1) {
    my $self = shift;

    # GIVEN
    $self->{config}{creature_factor_level_increase_step} = 5;

    # WHEN
    my $factor = RPG::Schema::Creature->_calculate_factor( 6, 10, 1 );

    # THEN
    is( $factor, 16, "Factor calculated correctly" );
}

1;
