use strict;
use warnings;

package Test::RPG::Combat::Battle;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::CreatureGroup;
use Test::RPG::Builder::Item;

use Data::Dumper;
use DateTime;

use RPG::Combat::Battle;

sub test_get_combatant_list_no_history_multiple_combatants : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
    
    my @combatants = ($party->characters, $cg->creatures);
    
    my $battle = Test::MockObject->new();
    my $session = {attack_history => {}};
    $battle->mock('session', sub { return $session });
    
    # WHEN
    my @sorted_combatants = RPG::Combat::Battle::get_combatant_list($battle, @combatants);
    
    # THEN
    is(scalar @sorted_combatants, scalar @combatants, "No one has extra attacks");
}

sub test_get_combatant_list_attack_history_updated : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $character = Test::MockObject->new();
    $character->set_always('number_of_attacks', 2);
    $character->set_true('is_character');
    $character->set_always('id', 1);
    
    my $creature = Test::MockObject->new();
    $creature->set_always('number_of_attacks', 1);
    $creature->set_false('is_character');
    $creature->set_always('id', 1);
    
    my $battle = Test::MockObject->new();
    my $session = {attack_history => {}};
    $battle->mock('session', sub { return $session });
    
    # WHEN
    my @sorted_combatants = RPG::Combat::Battle::get_combatant_list($battle, $character, $creature);
    
    # THEN
    is($session->{attack_history}{character}{1}[0], 2, "Session updated for character");
    is($session->{attack_history}{creature}{1}[0], 1, "Session updated for creature");
}

sub test_get_combatant_list_with_history : Tests(5) {
    my $self = shift;
    
    # GIVEN
    my $character = Test::MockObject->new();
    $character->set_always('number_of_attacks', 2);
    $character->set_true('is_character');
    $character->set_always('id', 1);
        
    my $battle = Test::MockObject->new();
    my $session = {attack_history => {'character' => { '1' => [2,2] }}};
    $battle->mock('session', sub { return $session });
   
    # WHEN
    my @sorted_combatants = RPG::Combat::Battle::get_combatant_list($battle, $character);
    
    # THEN
    is(scalar @sorted_combatants, 2, "Character added twice");

    my ($name, $args) = $character->next_call(4);
    is($name, 'number_of_attacks', "Number of attacks called");
    is($args->[1], 2, "First attack history passed");
    is($args->[2], 2, "Second attack history passed");
    is($session->{attack_history}{character}{1}[2], 2, "Session updated for character");
}

sub test_check_character_attack : Tests(3) {
    my $self = shift;
    
    # GIVEN
    my $attacker = Test::MockObject->new();
    $attacker->set_always('id',1);

    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        variables => [
            {
                item_variable_name => 'Durability',
                item_variable_value  => 1,
            }
        ]
    );
    
    is($item->variable('Durability'), 1, "Created item's durability set");
    
    my $character_weapons = {};
    $character_weapons->{1}{id} = $item->id;
    $character_weapons->{1}{durability} = 1;
    
    my $battle = Test::MockObject->new();
    $battle->set_always('character_weapons', $character_weapons);    
    $battle->set_always('schema', $self->{schema});
    $battle->set_always('log', $self->{mock_logger});
    
    $self->mock_dice;
    $self->{roll_result} = 1;
  
    # WHEN
    my $ret = RPG::Combat::Battle::check_character_attack($battle, $attacker);
    
    # THEN
    is_deeply($ret, {weapon_broken => 1}, "Weapon broken message returned");
    
    $item->discard_changes;
    is($item->variable('Durability'), 0, "Item's durability updated");    
        
}

sub test_check_character_attack_with_ammo : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $attacker = Test::MockObject->new();
    $attacker->set_always('id',2);

    my $ammo1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => 2,
        super_category_name => 'Ammo',
        category_name       => 'Ammo',
        variables => [
            {
                item_variable_name => 'Quantity',
                item_variable_value => 5,
            
            },
        ]
    );
        
    my $character_weapons = {};        
    $character_weapons->{2}{id} = 1;
    $character_weapons->{2}{durability} = 1;
    $character_weapons->{2}{ammunition} = [
        {
            id => $ammo1->id,
            quantity => 5,
        },
        # Non-existant ammo should not be read (will die if it is)
        {
            id => 55,
            quantity => 99,
        }
    ];
    
    my $battle = Test::MockObject->new();
    $battle->set_always('character_weapons', $character_weapons);    
    $battle->set_always('schema', $self->{schema});    
    $battle->set_always('log', $self->{mock_logger});
    
    $self->mock_dice;
    $self->{roll_result} = 2;
  
    # WHEN
    my $ret = RPG::Combat::Battle::check_character_attack($battle, $attacker);
    
    # THEN
    is($ret, undef, "No messages returned");
    
    $ammo1->discard_changes;
    is($ammo1->variable('Quantity'), 4, "Quantity of ammo updated");
}

sub test_check_character_attack_with_ammo_run_out : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $attacker = Test::MockObject->new();
    $attacker->set_always('id',2);

    my $ammo1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => 2,
        super_category_name => 'Ammo',
        category_name       => 'Ammo',
        variables => [
            {
                item_variable_name => 'Quantity',
                item_variable_value => 0,
            
            },
        ]
    );
            
    my $character_weapons = {};              
    $character_weapons->{2}{id} = 1;
    $character_weapons->{2}{durability} = 1;
    $character_weapons->{2}{ammunition} = [
        {
            id => $ammo1->id,
            quantity => 0,
        },
    ];
    
    my $battle = Test::MockObject->new();
    $battle->set_always('character_weapons', $character_weapons);    
    $battle->set_always('schema', $self->{schema});    
    $battle->set_always('log', $self->{mock_logger});
    
    $self->mock_dice;    
    $self->{roll_result} = 2;
  
    # WHEN
    my $ret = RPG::Combat::Battle::check_character_attack($battle, $attacker);
    
    # THEN
    is_deeply($ret, { no_ammo => 1 }, "No ammo message returned");
    
    $ammo1->discard_changes;
    is($ammo1->in_storage, 0, "Ammo deleted");    
        
}

sub test_check_character_attack_with_ammo_last_shot : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $attacker = Test::MockObject->new();
    $attacker->set_always('id',2);

    my $ammo1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => 2,
        super_category_name => 'Ammo',
        category_name       => 'Ammo',
        variables => [
            {
                item_variable_name => 'Quantity',
                item_variable_value => 0,
            
            },
        ]
    );
            
    my $character_weapons = {};              
    $character_weapons->{2}{id} = 1;
    $character_weapons->{2}{durability} = 1;
    $character_weapons->{2}{ammunition} = [
        {
            id => $ammo1->id,
            quantity => 1,
        },
    ];
    
    my $battle = Test::MockObject->new();
    $battle->set_always('character_weapons', $character_weapons);    
    $battle->set_always('schema', $self->{schema});    
    $battle->set_always('log', $self->{mock_logger});
    
    $self->mock_dice;    
    $self->{roll_result} = 2;
  
    # WHEN
    my $ret = RPG::Combat::Battle::check_character_attack($battle, $attacker);
    
    # THEN
    is($ret, undef, "No message returned");
    
    $ammo1->discard_changes;
    is($ammo1->in_storage, 0, "Ammo deleted");    
        
}

sub test_distribute_xp : Tests(12) {
	my $self = shift;
	
	my @tests = (
		{
			xp => 100,
			characters => {
				'1' => {
					damage_done => 10,
					attack_count => 5,
				},
				'2' => {
					damage_done => 10,
					attack_count => 5,
				},
			},
			result => {
				1 => 50,
				2 => 50,	
			},
			description => 'Two chars, take 50% each',
		},
	
		{
			xp => 100,
			characters => {
				'1' => {
					damage_done => 10,
					attack_count => 5,
				},
				'2' => {
					damage_done => 10,
					attack_count => 5,
				},
				'3' => {
					damage_done => 10,
					attack_count => 5,
				},	
				'4' => {
					damage_done => 0,
					attack_count => 0,
				},	
				'5' => {
					damage_done => 0,
					attack_count => 0,
				},											
			},
			result => {
				1 => 27,
				2 => 27,
				3 => 27,
				4 => 10,
				5 => 10,	
			},
			description => 'Two chars take minimum, three chars, take 30% each',
		},
		
		{
			xp => 100,
			characters => {
				'1' => {
					damage_done => 75,
					attack_count => 0,
				},
				'2' => {
					damage_done => 0,
					attack_count => 75,
				},
				'3' => {
					damage_done => 25,
					attack_count => 25,
				},															
			},
			result => {
				1 => 37,
				2 => 33,
				3 => 30,	
			},
			description => 'Three chars get different shares because of weighting between damange_done / attack_count',
		},				
		
		{
			xp => 103,
			characters => {
				'1' => {
					damage_done => 10,
					attack_count => 5,
				},
				'2' => {
					damage_done => 10,
					attack_count => 5,
				},
			},
			result => {
				1 => 51,
				2 => 51,	
			},
			description => 'Two chars, take 50% each, odd number of xp',
		},		
		
	);
	
	foreach my $test (@tests) {
		my @char_ids;
		my %damage;
		my %attacks;

		foreach my $char_id (keys %{$test->{characters}}) {
			push @char_ids, $char_id;
			$damage{$char_id}  = $test->{characters}{$char_id}{damage_done};
			$attacks{$char_id} = $test->{characters}{$char_id}{attack_count};
		}
		
		# Setup session		
		my $session = {damage_done => \%damage, attack_count => \%attacks};
		my $battle = Test::MockObject->new();
		$battle->set_always('session', $session);
		
		my $dist_xp = RPG::Combat::Battle::distribute_xp($battle, $test->{xp}, \@char_ids);
		is_deeply($dist_xp, $test->{result}, $test->{description});
		
		is($self->{session}{damage_done},  undef, "Damage done cleared");
		is($self->{session}{attack_count}, undef, "Attack count cleared");
	}	
}

sub test_check_for_end_of_combat_cg_defeated : Tests(5) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, creature_hit_points_current => 0 );
    my $combatant = Test::MockObject->new();
    
    my $combat_log = Test::MockObject->new();
    $combat_log->set_true('outcome');
    $combat_log->set_true('encounter_ended');
    
    my $result = {};
        
	my $battle = Test::MockObject->new();
	$battle->set_always('opponent_number_of_group', 2);
	$battle->set_list('opponents', $party, $cg);
	$battle->set_always('combat_log', $combat_log);
	$battle->mock('result', sub { $result } );	
	$battle->set_always('finish');
	$battle->set_always('end_of_combat_cleanup');	
	
	# WHEN
	RPG::Combat::Battle::check_for_end_of_combat($battle, $combatant);
	
	# THEN
	my ($method, $args) = $combat_log->next_call();
	is($method, 'outcome', "outcome set on combat log");
	is($args->[1], 'opp1_won', "outcome set correctly");

	($method, $args) = $combat_log->next_call(1);
	is($method, 'encounter_ended', "encounter_ended set on combat log");
	isa_ok($args->[1], 'DateTime', "encounter_ended set to a datetime");
	
	is($result->{combat_complete}, 1, "Combat complete set");   
}

sub test_check_check_for_end_of_combat_defeated : Tests(6) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, hit_points => 0 );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, hit_points => 2 );
    my $combatant = Test::MockObject->new();
    
    my $combat_log = Test::MockObject->new();
    $combat_log->set_true('outcome');
    $combat_log->set_true('encounter_ended');
    
    my $result = {};
        
	my $battle = Test::MockObject->new();
	$battle->set_always('opponent_number_of_group', 1);
	$battle->set_list('opponents', $party, $cg);
	$battle->set_always('combat_log', $combat_log);
	$battle->mock('result', sub { $result } );
	$battle->set_always('finish');
	$battle->set_always('end_of_combat_cleanup');
	
	# WHEN
	RPG::Combat::Battle::check_for_end_of_combat($battle, $combatant);
	
	# THEN
	my ($method, $args) = $combat_log->next_call();
	is($method, 'outcome', "outcome set on combat log");
	is($args->[1], 'opp2_won', "outcome set correctly");

	($method, $args) = $combat_log->next_call(1);
	is($method, 'encounter_ended', "encounter_ended set on combat log");
	isa_ok($args->[1], 'DateTime', "encounter_ended set to a datetime");
	
	is($result->{combat_complete}, 1, "Combat complete set");
	
	$party->discard_changes;
	is(defined $party->defunct, 1, "Party now marked as defunct"); 
}

sub test_check_for_offline_cast_creature_target : Tests(3) {
	my $self = shift;

	# GIVEN
	my $spell = $self->{schema}->resultset('Spell')->find( { spell_name => 'Energy Beam', } );
	
	$self->{config} = {
		online_threshold => 5,
	};
	
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, creature_count => 1 );
    my $cret = ($cg->creatures)[0];
    
    $party->last_action(DateTime->now()->subtract( minutes => 10 ));	
    $party->update;
	
	my $character = Test::RPG::Builder::Character->build_character($self->{schema}, party_id => $party->id);
	$character = Test::MockObject::Extends->new($character);
	$character->set_true('is_spell_caster');
	$character->set_always('check_for_offline_cast', $spell);
	
	my $battle = Test::MockObject->new();
	$battle->set_always('opponents_of', $cg);
	
	# WHEN
	RPG::Combat::Battle::check_for_offline_cast($battle, $character);
	
	# THEN
	is($character->last_combat_action, 'Cast', "Last combat action set correctly");
	is($character->last_combat_param1, $spell->id, "Spell id set correctly");
	is($character->last_combat_param2, $cret->id, "Spell target set correctly");	

}

sub test_check_for_offline_cast_character_target : Tests(3) {
	my $self = shift;

	# GIVEN
	my $spell = $self->{schema}->resultset('Spell')->find( { spell_name => 'Haste', } );
	
	$self->{config} = {
		online_threshold => 5,
	};
	
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, creature_count => 1 );
    my $cret = ($cg->creatures)[0];
    
    $party->last_action(DateTime->now()->subtract( minutes => 10 ));	
    $party->update;
	
	my $character = Test::RPG::Builder::Character->build_character($self->{schema}, party_id => $party->id);
	$character = Test::MockObject::Extends->new($character);
	$character->set_true('is_spell_caster');
	$character->set_always('check_for_offline_cast', $spell);
	
	my $battle = Test::MockObject->new();
	$battle->set_always('opponents_of', $cg);
	
	# WHEN
	RPG::Combat::Battle::check_for_offline_cast($battle, $character);
	
	# THEN
	is($character->last_combat_action, 'Cast', "Last combat action set correctly");
	is($character->last_combat_param1, $spell->id, "Spell id set correctly");
	is($character->last_combat_param2, $character->id, "Spell target set correctly");	

}

sub test_check_for_offline_cast_online_so_no_cast : Tests(3) {
	my $self = shift;

	# GIVEN
	my $spell = $self->{schema}->resultset('Spell')->find( { spell_name => 'Haste', } );
	
	$self->{config} = {
		online_threshold => 11,
	};
	
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, creature_count => 1 );
    my $cret = ($cg->creatures)[0];
    
    $party->last_action(DateTime->now()->subtract( minutes => 10 ));	
    $party->update;
	
	my $character = Test::RPG::Builder::Character->build_character($self->{schema}, party_id => $party->id);
	$character->last_combat_action('Defend');
	$character->update;
	$character = Test::MockObject::Extends->new($character);
	$character->set_true('is_spell_caster');
	$character->set_always('check_for_offline_cast', $spell);
	
	my $battle = Test::MockObject->new();
	$battle->set_always('opponents_of', $cg);
	
	# WHEN
	RPG::Combat::Battle::check_for_offline_cast($battle, $character);
	
	# THEN
	is($character->last_combat_action, 'Defend', "Last combat action set correctly");
	is($character->last_combat_param1, undef, "No spell id");
	is($character->last_combat_param2, undef, "No spell target");
}

1;