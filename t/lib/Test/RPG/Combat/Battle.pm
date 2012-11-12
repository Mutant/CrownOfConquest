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
use Test::RPG::Builder::Land;
use Test::RPG::Builder::Town;

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
    $battle->mock('sort_combatant_list', sub { shift; @_ });
    $battle->set_always('character_weapons',{});
    
    # WHEN
    my @sorted_combatants = RPG::Combat::Battle::get_combatant_list($battle, @combatants);
    
    # THEN
    is(scalar @sorted_combatants, scalar @combatants, "No one has extra attacks");
}

sub test_get_combatant_list_attack_history_updated : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character($self->{schema});  
    $character = Test::MockObject::Extends->new($character);
    $character->set_always('number_of_attacks', 2);
    $character->set_always('last_combat_action', 'Attack');
    
    my $creature = Test::MockObject->new();
    $creature->set_always('number_of_attacks', 1);
    $creature->set_false('is_character');
    $creature->set_always('id', 1);    
    
    my $battle = Test::MockObject->new();
    my $session = {attack_history => {}};
    $battle->mock('session', sub { return $session });
    $battle->mock('sort_combatant_list', sub { shift; @_ });
    $battle->set_always('character_weapons',{});
    
    # WHEN
    my @sorted_combatants = RPG::Combat::Battle::get_combatant_list($battle, $character, $creature);
    
    # THEN
    is($session->{attack_history}{character}{$character->id}[0], 2, "Session updated for character");
    is($session->{attack_history}{creature}{1}[0], 1, "Session updated for creature");
}

sub test_get_combatant_list_with_history : Tests(5) {
    my $self = shift;
    
    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character($self->{schema});  
    $character->last_combat_action('Attack');
    $character->update;
    
    $character = Test::MockObject::Extends->new($character);
    $character->set_always('number_of_attacks', 2);
        
    my $battle = Test::MockObject->new();
    my $session = {attack_history => {'character' => { $character->id => [2,2] }}};
    $battle->mock('session', sub { return $session });
    $battle->mock('sort_combatant_list', sub { shift; @_ });
    $battle->set_always('character_weapons',{});
   
    # WHEN
    my @sorted_combatants = RPG::Combat::Battle::get_combatant_list($battle, $character);
    
    # THEN
    is(scalar @sorted_combatants, 2, "Character added twice");

    my ($name, $args) = $character->next_call();
    is($name, 'number_of_attacks', "Number of attacks called");
    is($args->[2], 2, "First attack history passed");
    is($args->[3], 2, "Second attack history passed");
    is($session->{attack_history}{character}{$character->id}[2], 2, "Session updated for character");
}


sub test_get_combatant_list_spell_casters_always_have_only_one_attack : Tests() {
	my $self = shift;
	
	# GIVEN
    my $character = Test::RPG::Builder::Character->build_character($self->{schema});
    
    $character->last_combat_action('Cast');
    $character->update;
    
    $character = Test::MockObject::Extends->new($character);
    $character->set_always('number_of_attacks', 2);
    
        
    my $battle = Test::MockObject->new();
    my $session = {attack_history => {'character' => { $character->id => [2,2] }}};
    $battle->mock('session', sub { return $session });
    $battle->mock('sort_combatant_list', sub { shift; @_ });
    
    # WHEN
    my @sorted_combatants = RPG::Combat::Battle::get_combatant_list($battle, $character);
    
    # THEN
    is(scalar @sorted_combatants, 1, "Character only has 1 attack as they're casting");
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
    my $attacker = Test::RPG::Builder::Character->build_character($self->{schema});

    my $ammo1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $attacker->id,
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
    $character_weapons->{$attacker->id}{id} = 1;
    $character_weapons->{$attacker->id}{durability} = 1;
    $character_weapons->{$attacker->id}{ammunition} = [
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
    my $attacker = Test::RPG::Builder::Character->build_character($self->{schema});

    my $ammo1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $attacker->id,
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
    $character_weapons->{$attacker->id}{id} = 1;
    $character_weapons->{$attacker->id}{durability} = 1;
    $character_weapons->{$attacker->id}{ammunition} = [
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
    my $attacker = Test::RPG::Builder::Character->build_character($self->{schema});

    my $ammo1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $attacker->id,
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
    $character_weapons->{$attacker->id}{id} = 1;
    $character_weapons->{$attacker->id}{durability} = 1;
    $character_weapons->{$attacker->id}{ammunition} = [
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

sub test_distribute_xp : Tests(15) {
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
		{
			xp => 96,
			characters => {
				'1' => {
					damage_done => 0,
					attack_count => 0,
					spell_cast => 0,
				},
				'2' => {
					damage_done => 0,
					attack_count => 0,
					spells_cast => 1,
				},
			},
			result => {
				1 => 38,
				2 => 58,	
			},
			description => 'Two chars, one gets extra for casting spells',
		},		
		
	);
	
	foreach my $test (@tests) {
		my @char_ids;
		my %damage;
		my %attacks;
		my %spells_cast;

		foreach my $char_id (keys %{$test->{characters}}) {
			push @char_ids, $char_id;
			$damage{$char_id}  = $test->{characters}{$char_id}{damage_done};
			$attacks{$char_id} = $test->{characters}{$char_id}{attack_count};
			$spells_cast{$char_id} = $test->{characters}{$char_id}{spells_cast} // 0;
		}
		
		# Setup session		
		my $session = {damage_done => \%damage, attack_count => \%attacks, spells_cast => \%spells_cast};

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
	$battle->set_always('combatants_alive', {1 => 2, 2 => 0} );
	
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
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $land[0]->id );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, hit_points => 0, land_id => $land[8]->id );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, hit_points => 2 );
    my $combatant = Test::MockObject->new();
    
    my $combat_log = Test::MockObject->new();
    $combat_log->set_true('outcome');
    $combat_log->set_true('encounter_ended');
    
    my $result = {};
    my $combatants_alive = {1 =>0};
        
	my $battle = Test::MockObject->new();
	$battle->set_always('opponent_number_of_group', 1);
	$battle->set_list('opponents', $party, $cg);
	$battle->set_always('combatants_alive', $combatants_alive );
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
	is($party->land_id, $land[0]->id, "Party sent to nearby town"); 
}

sub test_check_for_auto_cast_creature_target : Tests(2) {
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
	$character->set_always('check_for_auto_cast', $spell);
	
	my $battle = Test::MockObject->new();
	$battle->set_always('opponents_of', $cg);
	$battle->mock('opposing_combatants_of', sub {($cg->members)});
	
	# WHEN
	my ($spell_cast, $target) = RPG::Combat::Battle::check_for_auto_cast($battle, $character);
	
	# THEN
	is($spell_cast->id, $spell->id, "Spell id set correctly");
	is($target->id, $cret->id, "Spell target set correctly");	

}

sub test_check_for_auto_cast_character_target : Tests(2) {
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
	$character->set_always('check_for_auto_cast', $spell);
	$character->set_always('last_combat_action', 'Attack');
	
	my $battle = Test::MockObject->new();
	$battle->set_always('opponents_of', $cg);
	$battle->mock('combatants', sub {($cg->members, $party->members)});
	
	# WHEN
	my ($spell_cast, $target) = RPG::Combat::Battle::check_for_auto_cast($battle, $character);
	
	# THEN
	is($spell_cast->id, $spell->id, "Spell id set correctly");
	is($target->id, $character->id, "Spell target set correctly");

}

sub test_check_for_auto_cast_online_so_no_cast : Tests(3) {
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
	
	my $battle = Test::MockObject->new();
	$battle->set_always('opponents_of', $cg);
	
	# WHEN
	RPG::Combat::Battle::check_for_auto_cast($battle, $character);
	
	# THEN
	is($character->last_combat_action, 'Defend', "Last combat action set correctly");
	is($character->last_combat_param1, undef, "No spell id");
	is($character->last_combat_param2, undef, "No spell target");
}

1;