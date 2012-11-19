use strict;
use warnings;

package Test::RPG::Schema::Party;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Day;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::Garrison;
use Test::RPG::Builder::Kingdom;
use Test::RPG::Builder::Quest;
use Test::RPG::Builder::Item_Type;
use Test::RPG::Builder::Item;
use Test::RPG::Builder::Land;
use Test::RPG::Builder::CreatureGroup;

use Data::Dumper;
use DateTime;

sub startup : Tests(startup=>1) {
    my $self = shift;

    my $mock_config = Test::MockObject::Extra->new();

    $self->{config} = {};

    $mock_config->fake_module( 'RPG::Config', 'config' => sub { $self->{config} }, );
    
    $self->{mock_config} = $mock_config;

    use_ok 'RPG::Schema::Party';
}

sub shutdown : Tests(shutdown) {
	my $self = shift;
	$self->{mock_config}->unfake_module();	
}

sub test_new_day : Tests(1) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema});
    my $mock_party = Test::MockObject->new();
    $mock_party->set_always( 'turns', 100 );
    $mock_party->mock( 'characters', sub { () } );
    $mock_party->set_true('rest');
    $mock_party->set_true('update');
    $mock_party->set_true('add_to_day_logs');

    $self->{config} = {
        daily_turns         => 10,
        maximum_turns       => 200,
        min_heal_percentage => 10,
        max_heal_percentage => 20,
    };

    my $mock_new_day = Test::MockObject->new();
    $mock_new_day->set_always( 'id', 5 );

    # WHEN
    RPG::Schema::Party::new_day( $party, $mock_new_day );

    # THEN
    $party->discard_changes;
    is($party->rest, 0, "Rest is set to 0");

}

sub test_in_party_battle_with : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $party1 = Test::RPG::Builder::Party->build_party($self->{schema});
    my $party2 = Test::RPG::Builder::Party->build_party($self->{schema});
    
    my $battle = $self->{schema}->resultset('Party_Battle')->create(
        {
            complete => '',
        }
    );
    
    $self->{schema}->resultset('Battle_Participant')->create(
        {
            party_id => $party1->id,
            battle_id => $battle->id,
        }
    );
    
    $self->{schema}->resultset('Battle_Participant')->create(
        {
            party_id => $party2->id,
            battle_id => $battle->id,
        }
    );
    
    # WHEN
    my $p1_opp = $party1->in_party_battle_with;
    my $p2_opp = $party2->in_party_battle_with;
    
    # THEN
    is($p1_opp->id, $party2->id, "Party 1 in combat with party 2");
    is($p2_opp->id, $party1->id, "Party 2 in combat with party 1");
}

sub test_over_flee_threshold_no_damage : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 2, hit_points => 10, max_hit_points => 10);
    $party->flee_threshold(70);
    $party->update;
    
    # WHEN
    my $over = $party->is_over_flee_threshold;
    
    # THEN
    is($over, 0, "Party not over threshold");    
}

sub test_over_flee_threshold_on_threshold : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 2, hit_points => 7, max_hit_points => 10);
    $party->flee_threshold(70);
    $party->update;
    
    # WHEN
    my $over = $party->is_over_flee_threshold;
    
    # THEN
    is($over, 0, "Party not over threshold");    
}

sub test_over_flee_threshold_below_threshold : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 1, hit_points => 69, max_hit_points => 100);
    $party->flee_threshold(70);
    $party->update;
    
    # WHEN
    my $over = $party->is_over_flee_threshold;
    
    # THEN
    is($over, 1, "Party over threshold");    
}

sub test_over_flee_threshold_below_threshold_garrison_chars : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 1, hit_points => 69, max_hit_points => 100);
    my $garrison = Test::RPG::Builder::Garrison->build_garrison($self->{schema}, character_count => 1, hit_points => 100, max_hit_points => 100, party_id => $party->id);
    $party->flee_threshold(70);
    $party->update;
    
    # WHEN
    my $over = $party->is_over_flee_threshold;
    
    # THEN
    is($over, 1, "Party over threshold");    
}


sub test_is_online_party_online : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 1, hit_points => 69, max_hit_points => 100);
    $party->last_action(DateTime->now());
    $party->update;
    
    $self->{config}{online_threshold} = 100;
    
    # WHEN
    my $online = $party->is_online;
    
    # THEN
    is($online, 1, "Party is online");    
}

sub test_is_online_party_offline : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 1, hit_points => 69, max_hit_points => 100);
    $party->last_action(DateTime->now()->subtract( minutes => 2 ));
    $party->update;
    
    $self->{config}{online_threshold} = 1;
    
    # WHEN
    my $online = $party->is_online;
    
    # THEN
    is($online, 0, "Party is offline");    
}

sub test_turns_used_incremented : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema},);
    my $day = Test::RPG::Builder::Day->build_day($self->{schema},);
    
    $self->{config}{maximum_turns} = 100;
    
    # WHEN
    $party->turns(50);
    $party->update;
    
    # THEN
    $party->discard_changes;
    is($party->turns_used, 50, "Correct number of turns used recorded");
}

sub test_turns_used_party_above_maximum_turns : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema},);
    my $day = Test::RPG::Builder::Day->build_day($self->{schema},);
    
    # Party has 100, but max is 99... this could happen if e.g. the max turns was reduced
    $self->{config}{maximum_turns} = 99;
    
    # WHEN
    $party->turns(99);
    $party->update;
    
    # THEN
    $party->discard_changes;
    is($party->turns_used, 1, "Correct number of turns used recorded");
}

sub test_turns_used_not_increased_when_adding_turns : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema},);
    my $day = Test::RPG::Builder::Day->build_day($self->{schema},);
    
    $self->{config}{maximum_turns} = 101;
    
    # WHEN
    $party->increase_turns(102);
    $party->update;
    
    # THEN
    $party->discard_changes;
    is($party->turns_used, 0, "Correct number of turns used recorded");
}

sub test_turns_not_lost_if_above_maximum : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema},);
    my $day = Test::RPG::Builder::Day->build_day($self->{schema},);
    
    # Party has 100, but max is 99... this could happen if e.g. the max turns was reduced
    $self->{config}{maximum_turns} = 98;
    
    # WHEN
    $party->turns(99);
    $party->update;
    
    # THEN
    $party->discard_changes;
    is($party->turns, 99, "Turns allowed to remain above maximum");
}

sub test_turns_cant_by_increased_by_calling_turns_method : Tests(3) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema},);
    my $day = Test::RPG::Builder::Day->build_day($self->{schema},);
    
    $self->{config}{maximum_turns} = 100;
    
    # WHEN
    my $e;
    eval {
        $party->turns(101);
        $party->update;
    };
    if ($@) {
        $e = $@;        
    }    
    
    # THEN
    isa_ok($e, 'RPG::Exception', "Exception thrown");
    is($e->type, 'increase_turns_error', "Exception is correct type");
    $party->discard_changes;
    is($party->turns, 100, "Turns not changed");
}

sub test_turns_cant_by_decreased_by_calling_increase_turns_method : Tests(3) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema},);
    my $day = Test::RPG::Builder::Day->build_day($self->{schema},);
    
    $self->{config}{maximum_turns} = 100;
    
    # WHEN
    my $e;
    eval {
        $party->increase_turns(99);
        $party->update;
    };
    if ($@) {
        $e = $@;        
    }    
    
    # THEN
    isa_ok($e, 'RPG::Exception', "Exception thrown");
    is($e->type, 'increase_turns_error', "Exception is correct type");
    $party->discard_changes;
    is($party->turns, 100, "Turns not changed");
}

sub test_turns_cant_be_increased_above_maximum : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema},);
    my $day = Test::RPG::Builder::Day->build_day($self->{schema},);
    
    $self->{config}{maximum_turns} = 105;
    
    # WHEN
    $party->increase_turns(110);
    $party->update;
    
    # THEN
    $party->discard_changes;
    is($party->turns, 105, "Turns set to maximum");
}

sub test_turns_allowed_to_stay_above_maximum_when_increased : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema},);
    my $day = Test::RPG::Builder::Day->build_day($self->{schema},);
    
    $self->{config}{maximum_turns} = 100;
    $party->_turns(105);
    $party->update;
    
    # WHEN
    $party->increase_turns(110);
    $party->update;
    
    # THEN
    $party->discard_changes;
    is($party->turns, 105, "Turns still above maximum");
}

sub test_disband : Tests(3) {
	my $self = shift;
	
	# GIVEN	
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 3);
    my $garrison = Test::RPG::Builder::Garrison->build_garrison($self->{schema}, party_id => $party->id);
    my $character = ($party->characters)[0];
    my $town = Test::RPG::Builder::Town->build_town($self->{schema});
    $character->mayor_of($town->id);
    $character->update;
    
    # WHEN
    $party->disband;
    
    # THEN
    is(defined $party->defunct, 1, "Party now defunct");
    
    $character->discard_changes;
    is($character->mayor_of, undef, "Mayor no longer a mayor");
    
    $garrison->discard_changes;
    is($garrison->land_id, undef, "Garrison removed from map");
}

sub test_deactivate_with_king : Tests(3) {
	my $self = shift;
	
	# GIVEN	
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema}, create_king => 0);
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, kingdom_id => $kingdom->id );
    my ($king) = $party->characters;
    $king->status('king');
    $king->status_context($kingdom->id);
    $king->update;
    
    # WHEN
    $party->deactivate;
    
    # THEN
    is(defined $party->defunct, 1, "Party now defunct");
    
    $king->discard_changes;
    is($king->party_id, undef, "King now an NPC");    
}

sub test_number_alive : Tests(1) {
	my $self = shift;
	
	# GIVEN	
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 2); 
    my @characters = $party->characters;
    
    $characters[0]->hit_points(0);
    $characters[0]->update; 
    
    # WHEN
    my $number_alive = $party->number_alive;
    
    # THEN
    is($number_alive, 1, "1 character is alive");
}

sub test_number_alive_only_includes_character_in_party : Tests(1) {
	my $self = shift;
	
	# GIVEN	
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 4); 
    my $garrison = Test::RPG::Builder::Garrison->build_garrison($self->{schema}, party_id => $party->id);  
    my @characters = $party->characters;
    
    $characters[0]->hit_points(0);
    $characters[0]->update; 

    $characters[1]->garrison_id($garrison->id);
    $characters[1]->update;

    $characters[2]->mayor_of(1);
    $characters[2]->update;

    $characters[3]->status('inn');
    $characters[3]->update;
    
    # WHEN
    my $number_alive = $party->number_alive;
    
    # THEN
    is($number_alive, 0, "No characters with party are alive");
}

sub test_change_allegiance : Tests() {
	my $self = shift;
	
	# GIVEN
	my $old_kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});	
    my $new_kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, kingdom_id => $old_kingdom->id);
    my $quest1 = Test::RPG::Builder::Quest->build_quest($self->{schema}, 
        quest_type => 'claim_land', kingdom_id => $old_kingdom->id, party_id => $party->id, status => 'In Progress'
    );

    my $quest2 = Test::RPG::Builder::Quest->build_quest($self->{schema}, 
        quest_type => 'claim_land', kingdom_id => $old_kingdom->id, party_id => $party->id, status => 'Complete'
    );
    
    # WHEN
    $party->change_allegiance($new_kingdom);
    $party->update;
    
    # THEN
    is($party->kingdom_id, $new_kingdom->id, "Kingdom id of party updated");
    
    is(scalar $old_kingdom->messages, 1, "Old kingdom gets a message");
    is(scalar $new_kingdom->messages, 1, "New kingdom gets a message");
    
    my @quests = $party->search_related('quests',
        {
            kingdom_id => $old_kingdom->id,
        }
    );
    is(scalar @quests, 2, "party has 2 kingdom quests");
    is($quests[0]->status, 'Terminated', "first quest was terminated");
    is($quests[1]->status, 'Complete', "second quest is still complete");        
}

sub test_give_item_to_character : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 3);
    my $item1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
    );    
    
    
    my @characters = $party->characters;
    
    $characters[0]->encumbrance(50);
    $characters[0]->create_item_grid;
    $characters[0]->update;

    $characters[1]->encumbrance(30);
    $characters[1]->create_item_grid;
    $characters[1]->update;
    
    $characters[2]->encumbrance(20);
    $characters[2]->hit_points(0);
    $characters[2]->create_item_grid;
    $characters[2]->update;    
    
    # WHEN
    my $character = $party->give_item_to_character($item1);
    
    # THEN
    is($character->id, $characters[1]->id, "Correct character returned");   
}

sub test_move_to : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land($self->{schema});
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 3, land_id => $land[0]->id);
    
    $party->add_to_mapped_sectors(
        {
            land_id  => $land[0]->id,
        },
    );    
    
    # WHEN
    $party->move_to($land[4]);
    
    # THEN
    my @mapped_sectors = $party->mapped_sectors;
    is(scalar @mapped_sectors, 9, "All sectors added to mapped sectors");   
}

sub test_flee_chance : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg($self->{schema}, creature_level => 3);
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 1, level => 7);
    
	$self->{config}{base_flee_chance}             = 50;
	$self->{config}{flee_chance_level_modifier}   = 5;
	$self->{config}{flee_chance_attempt_modifier} = 5;
	$self->{config}{flee_chance_low_level_bonus}  = 10;
	
	# WHEN
	my $chance = $party->flee_chance($cg);
	
	# THEN
	is($chance, 50, "Correct flee chance");    
}

sub test_flee_chance_with_tactics : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg($self->{schema}, creature_level => 3);
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 1, level => 7);
    
    my $char = Test::RPG::Builder::Character->build_character($self->{schema}, level => 3, creature_group_id => $cg->id);
    
    my $skill = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Tactics',
        }
    );
    
    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id => $skill->id,
            character_id => $char->id,
            level => 5,
        }
    );    

	$self->{config}{base_flee_chance}             = 50;
	$self->{config}{flee_chance_level_modifier}   = 5;
	$self->{config}{flee_chance_attempt_modifier} = 5;
	$self->{config}{flee_chance_low_level_bonus}  = 10;
	
	# WHEN
	my $chance = $party->flee_chance($cg);
	
	# THEN
	is($chance, 44, "Correct flee chance");
}

sub test_flee_chance_with_strategy : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg($self->{schema}, creature_level => 3);
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 1, level => 7);
    
    my ($char) = $party->characters;
    
    my $skill = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Strategy',
        }
    );
 
    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id => $skill->id,
            character_id => $char->id,
            level => 5,
        }
    ); 

	$self->{config}{base_flee_chance}             = 50;
	$self->{config}{flee_chance_level_modifier}   = 5;
	$self->{config}{flee_chance_attempt_modifier} = 5;
	$self->{config}{flee_chance_low_level_bonus}  = 10;
	
	# WHEN
	my $chance = $party->flee_chance($cg);
	
	# THEN
	is($chance, 56, "Correct flee chance");
}

sub test_mayor_count_allowed : Tests(6) {
    my $self = shift;
    
    # GIVEN
    my @tests = (
        {
            char_levels => ['7'],
            expected_result => 0,
            description => 'No mayors allowed as under min level',
        }, 
        {
            char_levels => ['15'],
            expected_result => 1,
            description => 'One mayor allowed, as above min level with no high level chars',
        },
        {
            char_levels => [qw/15 20 20 20/],
            expected_result => 2,
            description => 'Two mayors allowed, as above min level with 3 high level chars',
        },   
        {
            char_levels => [qw/19 20 20 20 25 22/],
            expected_result => 2,
            description => 'Two mayors allowed, as above min level with 5 high level chars',
        },     
        {
            char_levels => [qw/19 20 20 20 25 22 20 20 20 22/],
            expected_result => 3,
            description => 'Three mayors allowed, as above min level with 9 high level chars, one in inn',
            chars_in_inn => [qw/0 1/],
        },
        {
            char_levels => [qw/19 20 20 20 25 22 20 20 20 22/],
            expected_result => 2,
            description => 'Two mayors allowed, as above min level with 9 high level chars, one in inn, 3 dead',
            chars_in_inn => [qw/0 1/],
            dead_chars => [qw/2 3 6/],
        },        

    );
        
    # WHEN / THEN
    foreach my $test (@tests) {
        my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 0);
        my $char_count = 0;
        foreach my $char_level (@{$test->{char_levels}}) {            
            my $status = '';
            if ($char_count ~~ $test->{chars_in_inn}) {
               $status = 'inn';
            }
            
            my $hit_points = 100;
            if ($char_count ~~ $test->{dead_chars}) {
               $hit_points = 0;
            }
            
            my $char = Test::RPG::Builder::Character->build_character($self->{schema}, 
                level => $char_level, 
                party_id => $party->id, 
                status => $status,
                hit_points => $hit_points,
            );
            
            $char_count++;            
        }
        
        #foreach my $char ($party->characters) {
        #    diag "Char, level: " . $char->level . ", status: " . $char->status . ", hps: " . $char->hit_points;   
        #}
        
        my $count = $party->mayor_count_allowed;    
        is($count, $test->{expected_result}, $test->{description});
    }
}

1;

