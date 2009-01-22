use strict;
use warnings;

package Test::RPG::Schema::Quest::Destroy_Orb;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use RPG::Schema::Quest::Destroy_Orb;

sub test_check_action_from_another_party_deletes_not_started_quest : Tests(2) {
    my $self = shift;

    my $quest = Test::MockObject->new();
    $quest->set_always('param_start_value', 1);
    $quest->set_always('party', $quest);
    $quest->set_always('id', 1);
    $quest->set_always('status', 'Not Started');
    $quest->set_true('delete');
    
    my $mock_trigger_party = Test::MockObject->new();
    $mock_trigger_party->set_always('id', 2);
    
    my $quest_affected = RPG::Schema::Quest::Destroy_Orb::check_action_from_another_party($quest, $mock_trigger_party, 'orb_destroyed', 1);
    
    is($quest_affected, 1, "Quest was affected");
    $quest->called_ok('delete', "Quest was deleted");    
    

}

1;
