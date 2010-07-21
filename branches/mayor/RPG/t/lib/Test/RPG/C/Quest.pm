use strict;
use warnings;

package Test::RPG::C::Quest;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Party;

use RPG::C::Quest;

sub test_check_action_only_in_progress_quests_checked : Tests(2) {
    my $self = shift;

    # GIVEN
    use_ok('Test::RPG::Builder::Quest::Destroy_Orb');
    
    $self->{config}{quest_type_vars}{destroy_orb}{initial_search_range} = 1;
    $self->{config}{quest_type_vars}{destroy_orb}{max_search_range} = undef;

    #use Data::Dumper;
    #warn Dumper $self->{c}->config;
    
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
 
    my $counter = 0;
    $self->{mock_forward}->{'RPG::V::TT'} = sub { return 'message: ' . $counter++ };

   
    # WHEN
    my $messages = RPG::C::Quest->check_action($self->{c}, 'orb_destroyed', 1);
    
    # THEN
    is(scalar @$messages, 1, "One message returned");
    

}

1;
