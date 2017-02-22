use strict;
use warnings;

package Test::RPG::C::Quest;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Quest::Destroy_Orb;

use RPG::C::Quest;

sub test_check_action_only_in_progress_quests_checked : Tests(1) {
    my $self = shift;

    # GIVEN
    $self->{config}{quest_type_vars}{destroy_orb}{initial_search_range} = 1;
    $self->{config}{quest_type_vars}{destroy_orb}{max_search_range}     = undef;

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $quest1 = Test::RPG::Builder::Quest::Destroy_Orb->build_quest( $self->{schema}, status => 'In Progress', party_id => $party->id );
    my $quest2 = Test::RPG::Builder::Quest::Destroy_Orb->build_quest( $self->{schema}, status => 'Complete', party_id => $party->id );

    my $quest_param1 = $quest1->param_record('Orb To Destroy');
    $quest_param1->start_value(1);
    $quest_param1->update;

    my $quest_param2 = $quest2->param_record('Orb To Destroy');
    $quest_param2->start_value(1);
    $quest_param2->update;

    $self->{stash}{party} = $party;

    # WHEN
    my $messages = RPG::C::Quest->check_action( $self->{c}, 'orb_destroyed', 1 );

    # THEN
    is( scalar @$messages, 1, "One message returned" );
}

sub test_check_action_checks_quests_related_to_action : Tests(2) {
    my $self = shift;

    # GIVEN
    $self->{config}{quest_type_vars}{destroy_orb}{initial_search_range} = 1;
    $self->{config}{quest_type_vars}{destroy_orb}{max_search_range}     = undef;

    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $quest = Test::RPG::Builder::Quest::Destroy_Orb->build_quest( $self->{schema}, status => 'In Progress', party_id => $party2->id );

    $self->{stash}{party} = $party1;

    my $counter = 0;

    # WHEN
    my $messages = RPG::C::Quest->check_action( $self->{c}, 'orb_destroyed', $quest->param_start_value('Orb To Destroy') );

    # THEN
    is( scalar @$messages, 0, "No messages returned" );

    $quest->discard_changes;
    is( $quest->status, 'Terminated', "Quest terminated, as a related action was completed" );

}

1;
