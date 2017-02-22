use strict;
use warnings;

package Test::RPG::NewDay::Quest;

use base qw(Test::RPG::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Day;
use Test::RPG::Builder::Quest::Destroy_Orb;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Quest;
use Test::RPG::Builder::Kingdom;

sub startup : Test(startup => 1) {
    my $self = shift;

    use_ok 'RPG::NewDay::Action::Quest';

    $self->setup_context;
}

sub test_update_days_left : Tests(6) {
    my $self = shift;

    # GIVEN
    my $mock_context = Test::MockObject->new();
    $mock_context->set_always( 'schema',      $self->{schema} );
    $mock_context->set_always( 'config',      $self->{config} );
    $mock_context->set_always( 'current_day', $self->{stash}{today} );
    $mock_context->set_isa('RPG::NewDay::Context');

    $self->{config}{quest_type_vars}{destroy_orb}{initial_search_range} = 3;
    $self->{config}{quest_type_vars}{destroy_orb}{max_search_range}     = 3;
    $self->{config}{quest_type_vars}{destroy_orb}{xp_per_distance}      = 1;
    $self->{config}{quest_type_vars}{destroy_orb}{gold_per_distance}    = 1;

    my $quest1 = Test::RPG::Builder::Quest::Destroy_Orb->build_quest( $self->{schema} );
    my $quest2 = Test::RPG::Builder::Quest::Destroy_Orb->build_quest( $self->{schema} );

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    $quest1->party_id( $party->id );
    $quest1->status('In Progress');
    $quest1->update;
    my $quest1_days_left = $quest1->days_to_complete;

    $quest2->party_id( $party->id );
    $quest2->status('In Progress');
    $quest2->days_to_complete(1);
    $quest2->update;

    # WHEN
    my $quest_action = RPG::NewDay::Action::Quest->new( context => $mock_context, );
    $quest_action->update_days_left();

    # THEN
    $quest1->discard_changes;
    is( $quest1->days_to_complete, $quest1_days_left - 1, "Quest 1 has days to complete reduced by 1" );
    is( $quest1->status, 'In Progress', "Quest 1 still in progress" );

    $quest2->discard_changes;
    is( $quest2->days_to_complete, 0, "Quest 2 days to complete is 0" );
    is( $quest2->status, 'Terminated', "Quest 2 terminated" );

    my $party_town = $self->{schema}->resultset('Party_Town')->find(
        {
            party_id => $party->id,
            town_id  => $quest2->town->id,
        }
    );
    is( $party_town->prestige, -3, "Prestige reduced" );

    my $message = $self->{schema}->resultset('Party_Messages')->find( { party_id => $party->id, } );
    is( $message->day_id, $mock_context->current_day->id, "Message created for party with correct day" );

}

sub test_complete_quests : Tests(4) {
    my $self = shift;

    # GIVEN
    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );

    my $kindgom = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );

    my $quest1 = Test::RPG::Builder::Quest::Destroy_Orb->build_quest( $self->{schema}, party_id => $party1->id, status => 'Awaiting Reward' );
    my $quest2 = Test::RPG::Builder::Quest->build_quest( $self->{schema}, party_id => $party2->id, quest_type => 'claim_land',
        kingdom_id => $kindgom->id, status => 'Awaiting Reward' );

    my $action = RPG::NewDay::Action::Quest->new( context => $self->{mock_context} );

    # WHEN
    $action->complete_quests;

    # THEN
    $quest1->discard_changes;
    is( $quest1->status, 'Complete', "Quest 1 has status set correctly" );
    is( scalar $party1->messages, 1, "Message added to party 1" );

    $quest2->discard_changes;
    is( $quest2->status, 'Complete', "Quest 2 has status set correctly" );
    is( scalar $party2->messages, 1, "Message added to party 2" );
}

1;
