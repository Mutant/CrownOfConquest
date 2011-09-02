use strict;
use warnings;

package Test::RPG::NewDay::Kingdom;

use base qw(Test::RPG::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use Test::More;

use Test::RPG::Builder::Kingdom;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Quest;
use Test::RPG::Builder::Day;
use Test::RPG::Builder::Land;
use Test::RPG::Builder::Town;

sub setup : Test(setup => 1) {
    my $self = shift;

	use_ok 'RPG::NewDay::Action::Kingdom';

    $self->setup_context;  
}

sub test_generate_kingdom_quests_basic : Tests(5) {
    my $self = shift;
    
    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema}, gold => 100000);
    my $party1 = Test::RPG::Builder::Party->build_party($self->{schema}, kingdom_id => $kingdom->id, character_count => 2, character_level => 3);
    my $party2 = Test::RPG::Builder::Party->build_party($self->{schema}, kingdom_id => $kingdom->id, character_count => 2, character_level => 3);
    my $party3 = Test::RPG::Builder::Party->build_party($self->{schema}, kingdom_id => $kingdom->id, character_count => 2, character_level => 3);
    my $party4 = Test::RPG::Builder::Party->build_party($self->{schema}, kingdom_id => $kingdom->id, character_count => 2, character_level => 1); 
    
    $self->{config}{minimum_kingdom_quests} = 3;
        
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

sub test_generate_kingdom_quests_prexisting : Tests(4) {
    my $self = shift;
    
    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema}, gold => 100000);
    my $party1 = Test::RPG::Builder::Party->build_party($self->{schema}, kingdom_id => $kingdom->id, character_count => 2, character_level => 3);
    my $party2 = Test::RPG::Builder::Party->build_party($self->{schema}, kingdom_id => $kingdom->id, character_count => 2, character_level => 3);
    my $party3 = Test::RPG::Builder::Party->build_party($self->{schema}, kingdom_id => $kingdom->id, character_count => 2, character_level => 3);
    
    $self->{config}{minimum_kingdom_quests} = 3;
    
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

sub test_cancel_quests_awaiting_acceptance : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, kingdom_id => $kingdom->id);

    my $old_day = Test::RPG::Builder::Day->build_day($self->{schema}, day_number => $self->{mock_context}->current_day->day_number - 10 );

    my $quest = Test::RPG::Builder::Quest->build_quest($self->{schema}, 
        kingdom_id => $kingdom->id, quest_type => 'claim_land', day_offered => $old_day->id, party_id => $party->id);
   
    $self->{config}{kingdom_quest_offer_time_limit} = 10;
    
    my $action = RPG::NewDay::Action::Kingdom->new( context => $self->{mock_context} );
  
    # WHEN
    $action->cancel_quests_awaiting_acceptance($kingdom);
        
    # WHEN
    $quest->discard_changes;
    is($quest->status, 'Terminated', 'Quest marked as terminated');
    
    my @messages = $party->messages;
    is(scalar @messages, 1, "1 Message added to party");     
}

sub test_check_for_inactive_still_active : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
    my @land = Test::RPG::Builder::Land->build_land($self->{schema}, 'x_size' => 5, 'y_size' => 5);
    foreach my $land (@land) {        
        $land->kingdom_id($kingdom->id);
        $land->update;   
    }
    my $town = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $land[0]->id);
    
    my $action = RPG::NewDay::Action::Kingdom->new( context => $self->{mock_context} );
    
    # WHEN
    my $result = $action->check_for_inactive($kingdom);
    
    # THEN
    is($result, 0, "Kingdom not inactive");
    
    $kingdom->discard_changes;
    is($kingdom->active, 1, "Kingdom still active");
    
}

sub test_check_for_inactive_marked_inactive : Tests(14) {
    my $self = shift;
    
    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
    my @land = Test::RPG::Builder::Land->build_land($self->{schema}, 'x_size' => 3, 'y_size' => 3);
    foreach my $land (@land) {        
        $land->kingdom_id($kingdom->id);
        $land->update;
    }
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, kingdom_id => $kingdom->id, character_count => 2);
    my $character = $kingdom->king;
    
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema},
        kingdom_loyalty => {
            $kingdom->id => 30,
        }
    );
    
    my $party2 = Test::RPG::Builder::Party->build_party($self->{schema}, kingdom_id => $kingdom->id, character_count => 2);
    
    my $action = RPG::NewDay::Action::Kingdom->new( context => $self->{mock_context} );
    
    # WHEN
    my $result = $action->check_for_inactive($kingdom);
    
    # THEN
    is($result, 1, "Kingdom is now inactive");
    
    $kingdom->discard_changes;
    is($kingdom->active, 0, "Kingdom marked inactive");
    
    foreach my $land (@land) {
        $land->discard_changes;
        is($land->kingdom_id, undef, "Sector " . $land->x . ", " . $land->y . " made neutral");    
    }
    
    $character->discard_changes;
    is($character->status, undef, "Character is no longer king"); 
    
    $party2->discard_changes;
    is($party2->kingdom_id, undef, "Party 2 no longer loyal to kingdom");
    
    my $kingdom_town = $self->{schema}->resultset('Kingdom_Town')->find(
        {
            kingdom_id => $kingdom->id,
            town_id => $town->id,
        }
    );
    is($kingdom_town, undef, "Kingdom_Town records deleted"); 
       
}

sub test_adjust_party_loyalty : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, kingdom_id => $kingdom->id, character_count => 3);
    my @characters = $party->characters;
    
    my @towns;
    for (0..2) {
        push @towns, Test::RPG::Builder::Town->build_town($self->{schema});
        $characters[$_]->mayor_of($towns[$_]->id);
        $characters[$_]->update;   
    }
    
    my $loc = $towns[0]->location;
    $loc->kingdom_id($kingdom->id);
    $loc->update;
    
    my $action = RPG::NewDay::Action::Kingdom->new( context => $self->{mock_context} );
    
    # WHEN
    $action->adjust_party_loyalty($kingdom);
    
    # THEN
    my $party_kingdom = $self->{schema}->resultset('Party_Kingdom')->find(
        {
            party_id => $party->id,
            kingdom_id => $kingdom->id,
        }
    );
    is($party_kingdom->loyalty, -1, "Loyalty reduced due to disloyal towns");       
}

sub test_banish_parties : Tests(3) {
    my $self = shift;
    
    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
    my $party1 = Test::RPG::Builder::Party->build_party($self->{schema}, kingdom_id => $kingdom->id);
    my $party2 = Test::RPG::Builder::Party->build_party($self->{schema}, kingdom_id => $kingdom->id);
    
    $self->mock_dice;
    $self->{roll_result} = 20;
    
    $party1->add_to_party_kingdoms(
        {
            kingdom_id => $kingdom->id,
            loyalty => 0,
        }
    );    

    $party2->add_to_party_kingdoms(
        {
            kingdom_id => $kingdom->id,
            loyalty => -70,
        }
    );
    
    $self->{config}{npc_kingdom_min_parties} = 2;
    
    my $action = RPG::NewDay::Action::Kingdom->new( context => $self->{mock_context} );
    
    # WHEN
    $action->banish_parties($kingdom, $party1, $party2);
    
    # THEN
    $party1->discard_changes;
    is($party1->kingdom_id, $kingdom->id, "First party still in the kingdom");
    
    $party2->discard_changes;
    is($party2->kingdom_id, undef, "Second party was banished");
    
    my $party_kingdom = $party2->find_related(
        'party_kingdoms',
        {
            kingdom_id => $kingdom->id,
        }
    );
    cmp_ok($party_kingdom->banished_for, '>=', '10', "Banished for set"); 
    
    $self->unmock_dice;       
}

sub test_check_for_coop : Tests(6) {
    my $self = shift;
    
    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema}, create_king => 0);
    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, kingdom_id => $kingdom->id );
    my ($king) = $party1->characters;
    $king->status('king');
    $king->status_context($kingdom->id);
    $king->update;
    
    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, kingdom_id => $kingdom->id );
    my $party3 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, kingdom_id => $kingdom->id );
    
    $party1->player->add_to_logins(
        {
            ip => '10.10.10.10',
            login_date => DateTime->now->subtract( days => 3 ),
        }
    );


    $party2->player->add_to_logins(
        {
            ip => '10.10.10.10',
            login_date => DateTime->now->subtract( days => 9 ),
        }
    );
    
    my $action = RPG::NewDay::Action::Kingdom->new( context => $self->{mock_context} );
    
    # WHEN
    $action->check_for_coop($kingdom, $king);
    
    # THEN
    $party1->discard_changes;
    is($party1->warned_for_kingdom_co_op, undef, "Party 1 not warned for co op");
    is($party1->messages->count, 0, "No messages added to party 1");

    $party2->discard_changes;
    isa_ok($party2->warned_for_kingdom_co_op, 'DateTime', "Party 2 warned for co op");
    is($party2->messages->count, 1, "Message added to party 2");

    $party3->discard_changes;
    is($party3->warned_for_kingdom_co_op, undef, "Party 3 not warned for co op");
    is($party3->messages->count, 0, "No messages added to party 3");
    
}

sub force_co_op_change_of_allegiance : Tests(15) {
    my $self = shift;
    
    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema}, create_king => 0);
    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, kingdom_id => $kingdom->id );
    my ($king) = $party1->characters;
    $king->status('king');
    $king->status_context($kingdom->id);
    $king->update;
    
    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, kingdom_id => $kingdom->id, 
        warned_for_kingdom_co_op => DateTime->now->subtract( days => 7 ));
 
    my $party3 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2,
        warned_for_kingdom_co_op => DateTime->now->subtract( days => 7 ));
    my $party4 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, kingdom_id => $kingdom->id, 
        warned_for_kingdom_co_op => DateTime->now->subtract( days => 4 ));
        
    my $kingdom2 = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema}, create_king => 0);
    my $party5 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, kingdom_id => $kingdom2->id,
        warned_for_kingdom_co_op => DateTime->now->subtract( days => 7 ) );
    my ($king2) = $party5->characters;
    $king2->status('king');
    $king2->status_context($kingdom2->id);
    $king2->update;            
    
    my $party6 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, kingdom_id => $kingdom2->id,
        warned_for_kingdom_co_op => DateTime->now->subtract( days => 7 ) );    

    for my $party ($party1, $party2, $party3, $party4, $party5) {         
        $party->player->add_to_logins(
            {
                ip => '10.10.10.10',
                login_date => DateTime->now->subtract( days => 3 ),
            }
        );
    }
    $self->{config}{kingdom_co_op_grace} = 7;
    
    my $action = RPG::NewDay::Action::Kingdom->new( context => $self->{mock_context} );
    
    # WHEN
    $action->force_co_op_change_of_allegiance($kingdom, $king);
    
    # THEN
    $party2->discard_changes;
    is($party2->kingdom_id, undef, "Party 2's allegiance changed");
    is($party2->messages->count, 2, "1 message left for party 2");
    is($party2->warned_for_kingdom_co_op, undef, "Party 2 no longer warned for kingdom co op");

    $party3->discard_changes;
    is($party3->kingdom_id, undef, "Party 3 still free citizens");
    is($party3->messages->count, 0, "No messages left for party 3");
    is($party3->warned_for_kingdom_co_op, undef, "Party 3 no longer warned for kingdom co op");

    $party4->discard_changes;
    is($party4->kingdom_id, $kingdom->id, "Party 4 allegiance not changed");
    is($party4->messages->count, 0, "No messages left for party 4");
    is(defined $party4->warned_for_kingdom_co_op, 1, "Party 4 still warned for kingdom co op");

    $party5->discard_changes;
    is($party5->kingdom_id, $kingdom2->id, "Party 5 allegiance not changed");
    is($party5->messages->count, 0, "No messages left for party 5");
    is($party5->warned_for_kingdom_co_op, undef, "Party 5 no longer warned for kingdom co op");
    
    $party6->discard_changes;
    is($party6->kingdom_id, $kingdom2->id, "Party 6 allegiance not changed");
    is($party6->messages->count, 0, "No messages left for party 6");
    is($party6->warned_for_kingdom_co_op, undef, "Party 6 no longer warned for kingdom co op");

    
}


1;