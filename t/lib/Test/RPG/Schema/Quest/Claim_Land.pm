use strict;
use warnings;

package Test::RPG::Schema::Quest::Claim_Land;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::RPG::Builder::Kingdom;
use Test::RPG::Builder::Quest;
use Test::RPG::Builder::Party;

use Test::More;
use Test::MockObject;

sub test_check_action_not_complete : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $kindgom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
    my $party = Test::RPG::Builder::Party->build_party($self->{schema});
    my $quest = Test::RPG::Builder::Quest->build_quest($self->{schema}, quest_type => 'claim_land', kingdom_id => $kindgom->id, party_id => $party->id);
    
    $quest->define_quest_param( 'Amount To Claim', 10 );
    $quest->define_quest_param( 'Amount Claimed', 0 );
    $quest->update;    
    
    # WHEN
    my $result = $quest->check_action($party, 'claimed_land');
    
    # THEN
    is($result, 1, "Action accepted");
    
    $quest->discard_changes;
    is($quest->param_current_value('Amount Claimed'), 1, "Amount claimed incremented");
}

sub test_check_action_completed : Tests(3) {
    my $self = shift;
    
    # GIVEN
    my $kindgom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
    my $party = Test::RPG::Builder::Party->build_party($self->{schema});
    my $quest = Test::RPG::Builder::Quest->build_quest($self->{schema}, quest_type => 'claim_land', kingdom_id => $kindgom->id, party_id => $party->id);
    
    $quest->define_quest_param( 'Amount To Claim', 10 );
    $quest->define_quest_param( 'Amount Claimed', 9 );
    $quest->update;    
    
    # WHEN
    my $result = $quest->check_action($party, 'claimed_land');
    
    # THEN
    is($result, 1, "Action accepted");
    
    $quest->discard_changes;
    is($quest->param_current_value('Amount Claimed'), 10, "Amount claimed incremented");
    is($quest->status, "Awaiting Reward", "Quest status is now Awaiting Reward");
}

sub test_check_action_already_completed : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $kindgom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
    my $party = Test::RPG::Builder::Party->build_party($self->{schema});
    my $quest = Test::RPG::Builder::Quest->build_quest($self->{schema}, quest_type => 'claim_land', kingdom_id => $kindgom->id, party_id => $party->id);
    
    $quest->define_quest_param( 'Amount To Claim', 10 );
    $quest->define_quest_param( 'Amount Claimed', 10 );
    $quest->update;    
    
    # WHEN
    my $result = $quest->check_action($party, 'claimed_land');
    
    # THEN
    is($result, 0, "Action not accepted");
    
    $quest->discard_changes;
    is($quest->param_current_value('Amount Claimed'), 10, "Amount claimed still the same");
}

1;
