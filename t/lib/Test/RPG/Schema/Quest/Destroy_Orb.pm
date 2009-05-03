use strict;
use warnings;

package Test::RPG::Schema::Quest::Destroy_Orb;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Land;

use RPG::Schema::Quest::Destroy_Orb;

use Scalar::Util 'blessed';

sub setup_orb_quest : Tests(setup) {
    my $self = shift;

    $self->{dice} = $self->mock_dice;    
}

sub test_check_action_from_another_party_deletes_not_started_quest : Tests(2) {
    my $self = shift;

    my $quest = Test::MockObject->new();
    $quest->set_always( 'param_start_value', 1 );
    $quest->set_always( 'party',             $quest );
    $quest->set_always( 'id',                1 );
    $quest->set_always( 'status',            'Not Started' );
    $quest->set_true('delete');

    my $mock_trigger_party = Test::MockObject->new();
    $mock_trigger_party->set_always( 'id', 2 );

    my $quest_affected = RPG::Schema::Quest::Destroy_Orb::check_action_from_another_party( $quest, $mock_trigger_party, 'orb_destroyed', 1 );

    is( $quest_affected, 1, "Quest was affected" );
    $quest->called_ok( 'delete', "Quest was deleted" );

}

sub test_set_quest_params : Tests(7) {
    my $self = shift;

    # GIVEN
    my $schema = $self->{schema};
    my @land   = Test::RPG::Builder::Land->build_land($schema);

    my $town = $schema->resultset('Town')->create( { land_id => $land[4]->id, } );

    $self->{config}{quest_type_vars}{destroy_orb}{initial_search_range} = 3;
    $self->{config}{quest_type_vars}{destroy_orb}{xp_per_distance}      = 1;
    $self->{config}{quest_type_vars}{destroy_orb}{gold_per_distance}    = 1;

    my $quest_type = $schema->resultset('Quest_Type')->find( { 'quest_type' => 'destroy_orb' } );

    my $orb = $schema->resultset('Creature_Orb')->create(
        {
            level   => 1,
            land_id => $land[0]->id,
        }
    );

    $self->{rolls} = [ 50, 2 ];

    # WHEN
    my $quest = $schema->resultset('Quest')->create(
        {
            town_id       => $town->id,
            quest_type_id => $quest_type->id,
        }
    );

    # THEN
    is( $quest->quest_type_id, $quest_type->id, "Quest is of the correct type" );
    isa_ok( $quest, 'RPG::Schema::Quest::Destroy_Orb', "Quest blessed into correct class" );
    is( $quest->param_start_value('Orb To Destroy'), $orb->id, "Orb to destroy set correctly" );
    is( $quest->min_level,                           3,        "Minimum level set correctly" );
    is( $quest->xp_value,                            1,        "Xp value set correctly" );
    is( $quest->gold_value,                          20,       "Gold value set correctly" );
    is( $quest->days_to_complete,                    4,        "Days to complete set correctly" );
}

sub test_set_quest_params_no_orb_in_range : Tests(2) {
    my $self = shift;

    # GIVEN
    my $schema = $self->{schema};
    my @land   = Test::RPG::Builder::Land->build_land($schema);

    my $town = $schema->resultset('Town')->create( { land_id => $land[4]->id, } );

    $self->{config}{quest_type_vars}{destroy_orb}{initial_search_range} = 3;
    $self->{config}{quest_type_vars}{destroy_orb}{max_search_range}     = 3;
    $self->{config}{quest_type_vars}{destroy_orb}{xp_per_distance}      = 1;
    $self->{config}{quest_type_vars}{destroy_orb}{gold_per_distance}    = 1;

    my $quest_type = $schema->resultset('Quest_Type')->find( { 'quest_type' => 'destroy_orb' } );

    $self->{rolls} = [ 50, 2 ];

    # WHEN
    my $quest;
    my $e;
    eval { $quest = $schema->resultset('Quest')->create( { town_id => $town->id, quest_type_id => $quest_type->id, } ); };
    if ( my $ev_err = $@ ) {
        if ( blessed($ev_err) && $ev_err->isa("RPG::Exception") ) {
            $e = $ev_err;
        }
        else {
            fail("Got unexpected exception: $ev_err");
        }
    }

    # THEN
    is( $e->type, "quest_creation_error", "Correct exception thrown" );
    is( $quest, undef, "Quest deleted" );
}

sub test_set_quest_params_already_quest_for_orb : Tests(2) {
    my $self = shift;

    # GIVEN
    my $schema = $self->{schema};
    my @land   = Test::RPG::Builder::Land->build_land($schema);

    my $town = $schema->resultset('Town')->create( { land_id => $land[4]->id, } );

    $self->{config}{quest_type_vars}{destroy_orb}{initial_search_range} = 3;
    $self->{config}{quest_type_vars}{destroy_orb}{max_search_range}     = 3;
    $self->{config}{quest_type_vars}{destroy_orb}{xp_per_distance}      = 1;
    $self->{config}{quest_type_vars}{destroy_orb}{gold_per_distance}    = 1;

    my $quest_type = $schema->resultset('Quest_Type')->find( { 'quest_type' => 'destroy_orb' } );

    $self->{rolls} = [ 50, 2 ];

    my $orb = $schema->resultset('Creature_Orb')->create(
        {
            level   => 1,
            land_id => $land[0]->id,
        }
    );

    my $existing_quest = $schema->resultset('Quest')->create(
        {
            town_id       => $town->id,
            quest_type_id => $quest_type->id,
        }
    );

    # WHEN
    my $quest;
    my $e;
    eval { $quest = $schema->resultset('Quest')->create( { town_id => $town->id, quest_type_id => $quest_type->id, } ); };
    if ( my $ev_err = $@ ) {
        if ( blessed($ev_err) && $ev_err->isa("RPG::Exception") ) {
            $e = $ev_err;
        }
        else {
            fail("Got unexpected exception: $ev_err");
        }
    }

    # THEN
    is( $e->type, "quest_creation_error", "Correct exception thrown" );
    is( $quest, undef, "Quest deleted" );
}

1;
