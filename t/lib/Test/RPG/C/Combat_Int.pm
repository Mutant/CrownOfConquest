use strict;
use warnings;

package Test::RPG::C::Combat_Int;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Item;
use Test::RPG::Builder::CreatureGroup;

use Data::Dumper;

sub combat_startup : Test(startup => 1) {
    my $self = shift;

	$self->{dice} = Test::MockObject->fake_module( 
		'Games::Dice::Advanced',
		roll => sub { $self->{roll_result} || 0 }, 
	);
    
    use_ok('RPG::C::Combat');
}

sub test_process_effects_refreshes_stash : Tests(no_plan) {
    my $self = shift;
    
    my $creature_group = $self->{schema}->resultset('CreatureGroup')->create({         
    });
    
    my $creature_type = $self->{schema}->resultset('CreatureType')->create({
    });
    
    my $creature = $self->{schema}->resultset('Creature')->create({
        creature_group_id => $creature_group->id,
        creature_type_id => $creature_type->id,
	});
	
	my $party = Test::RPG::Builder::Party->build_party(
	   $self->{schema},
	);
	
	my $character = Test::RPG::Builder::Character->build_character(
	   $self->{schema},
	   party_id => $party->id,
	);
	
	my $effect1 = $self->{schema}->resultset('Effect')->create({
	    combat => 1,
	    time_left => 2,
	});

	my $effect2 = $self->{schema}->resultset('Effect')->create({
	    combat => 1,
	    time_left => 1,
	});
	
	my $creature_effect = $self->{schema}->resultset('Creature_Effect')->create({
	    creature_id => $creature->id,
	    effect_id => $effect1->id,
	});
	
	my $character_effect = $self->{schema}->resultset('Character_Effect')->create({
	    character_id => $character->id,
	    effect_id => $effect2->id,
	});
	
	$self->{stash} = {
	    creature_group => $self->{schema}->resultset('CreatureGroup')->get_by_id($creature_group->id),   
	    party => $self->{schema}->resultset('Party')->get_by_player_id($party->player_id),
	};
	
	$self->{session} = {
	    player => $party->player,
	};
	
	RPG::C::Combat->process_effects($self->{c});
	
	my @creatures = $self->{stash}->{creature_group}->creatures;
	my @effects = $creatures[0]->creature_effects;	
	
	is($effects[0]->effect->time_left, 1, "Time left on effect decreased to 1 on creature's effect");
	
	my @characters = $self->{stash}->{party}->characters;
	@effects = $characters[0]->character_effects;
	
	is(scalar @effects, 0, "No effects on character, as it has been deleted");
}

sub test_calculate_factors : Tests(3) {
    my $self = shift;
    
    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character($self->{schema});   
    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        variables => [
            {
                item_variable_name => 'Durability',
                item_variable_value  => 5,
            }
        ],
        attributes => [
            {
                item_attribute_name => 'Attack Factor',
                item_attribute_value => 5,
            },
            {
                item_attribute_name => 'Damage',
                item_attribute_value => 5,
            }            
        ],
        super_category_name => 'Weapon',
    );
    $item->character_id($character->id);
    $item->update;
        
    # WHEN
    RPG::C::Combat->calculate_factors($self->{c}, [ $character ]);
    
    # THEN
    is($self->{session}{character_weapons}{$character->id}{id}, $item->id, "Item id saved in session");
    is($self->{session}{character_weapons}{$character->id}{durability}, 5, "Item durability saved in session");
    is($self->{session}{character_weapons}{$character->id}{ammunition}, undef, "No ammo");
    
}

sub test_roll_flee_attempt : Tests(5) {
    my $self = shift;
    
    # GIVEN
    $self->{config}{base_flee_chance} = 50;
    $self->{config}{flee_chance_level_modifier} = 5;
    $self->{config}{flee_chance_attempt_modifier} = 5;
    $self->{config}{flee_chance_low_level_bonus} = 10;
    
    my %tests = (
        basic_test_success => {
            cg_level => 2,
            party_level => 2,
            roll => 50,
            expected_result => 1,
            previous_flee_attempts => 0,
        },
        basic_test_fail => {
            cg_level => 2,
            party_level => 2,
            roll => 51,
            expected_result => 0,
            previous_flee_attempts => 0,
        },        
        party_low_level => {
            cg_level => 6,
            party_level => 2,
            roll => 70,
            expected_result => 1,
            previous_flee_attempts => 0,
        },
        previous_attempts => {
            cg_level => 4,
            party_level => 2,
            roll => 70,
            expected_result => 1,
            previous_flee_attempts => 2,
        }, 
        level_1_party => {
            cg_level => 1,
            party_level => 1,
            roll => 60,
            expected_result => 1,
            previous_flee_attempts => 0,
        },               
    );
  
    # WHEN
    my %results;
    while (my ($test_name, $test_data) = each %tests) { 
        my $cg = Test::RPG::Builder::CreatureGroup->build_cg($self->{schema}, creature_level => $test_data->{cg_level});
    
        $self->{roll_result} = $test_data->{roll};
        
        $self->{session}{unsuccessful_flee_attempts} = $test_data->{previous_flee_attempts};
        
        my $party = Test::MockObject->new();
        $party->set_always('in_combat_with', $cg->id);
        $party->set_always('level', $test_data->{party_level});
        
        $self->{stash}{party} = $party;
        
        $results{$test_name} = RPG::C::Combat->roll_flee_attempt($self->{c});
    }   
    
    
    # THEN
    while (my ($test_name, $test_data) = each %tests) { 
        is($results{$test_name}, $test_data->{expected_result}, "Flee result as expected for test: $test_name");   
    }

}

1;