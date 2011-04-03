use strict;
use warnings;

package Test::RPG::NewDay::Kingdom;

use base qw(Test::RPG::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use Test::More;

use Test::RPG::Builder::Kingdom;
use Test::RPG::Builder::Party;

sub setup : Test(setup => 1) {
    my $self = shift;

	use_ok 'RPG::NewDay::Action::Kingdom';

    $self->setup_context;  
}

sub test_generate_kingdom_quests_basic : Tests(5) {
    my $self = shift;
    
    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
    my $party1 = Test::RPG::Builder::Party->build_party($self->{schema}, kingdom_id => $kingdom->id, character_count => 2, character_level => 3);
    my $party2 = Test::RPG::Builder::Party->build_party($self->{schema}, kingdom_id => $kingdom->id, character_count => 2, character_level => 3);
    my $party3 = Test::RPG::Builder::Party->build_party($self->{schema}, kingdom_id => $kingdom->id, character_count => 2, character_level => 3);
    my $party4 = Test::RPG::Builder::Party->build_party($self->{schema}, kingdom_id => $kingdom->id, character_count => 2, character_level => 1); 
    
    my $action = RPG::NewDay::Action::Kingdom->new( context => $self->{mock_context} );
    
    # WHEN
    $action->generate_kingdom_quests($kingdom, ($party1, $party2, $party3, $party4));
    
    # THEN   
    my @quests = $kingdom->quests;
    is(scalar @quests, 3, "3 quests generated for kingdom");
    
    is(scalar $party1->quests, 1, "1 quest generated for party 1");
    is(scalar $party2->quests, 1, "1 quest generated for party 2");
    is(scalar $party3->quests, 1, "1 quest generated for party 3");
    is(scalar $party4->quests, 0, "no quests for party 4, as they are not high enough level");    
}

sub test_generate_kingdom_quests_prexisting : Tests() {
    my $self = shift;
    
    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
    my $party1 = Test::RPG::Builder::Party->build_party($self->{schema}, kingdom_id => $kingdom->id, character_count => 2, character_level => 3);
    my $party2 = Test::RPG::Builder::Party->build_party($self->{schema}, kingdom_id => $kingdom->id, character_count => 2, character_level => 3);
    my $party3 = Test::RPG::Builder::Party->build_party($self->{schema}, kingdom_id => $kingdom->id, character_count => 2, character_level => 3);
    
    my $quest_type = $self->{schema}->resultset('Quest_Type')->find(
        {
            quest_type => 'claim_land',
        }
    );
    
    for my $party ($party1, $party3) {
        $self->{schema}->resultset('Quest')->create(
            {
                kingdom_id => $kingdom->id,
                party_id => $party->id,
                quest_type_id => $quest_type->id
            }
        );
    }

    my $action = RPG::NewDay::Action::Kingdom->new( context => $self->{mock_context} );
    
    # WHEN
    $action->generate_kingdom_quests($kingdom, ($party1, $party2, $party3));
    
    # THEN   
    my @quests = $kingdom->quests;
    is(scalar @quests, 3, "3 quests generated for kingdom");
    
    is(scalar $party1->quests, 1, "1 quest generated for party 1");
    is(scalar $party2->quests, 1, "1 quest generated for party 2");
    is(scalar $party3->quests, 1, "1 quest generated for party 3");    
   
}

1;