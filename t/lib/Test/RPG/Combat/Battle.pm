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
    
    $self->mock_dice;    
    $self->{roll_result} = 2;
  
    # WHEN
    my $ret = RPG::Combat::Battle::check_character_attack($battle, $attacker);
    
    # THEN
    is_deeply($ret, { no_ammo => 1 }, "No messages returned");
    
    $ammo1->discard_changes;
    is($ammo1->in_storage, 0, "Quantity of ammo updated");    
        
}

sub test_finish : Tests(12) {
	my $self = shift;
	
	# GIVEN
	my @creatures;
	for (1..5) {
		my $mock_creature_type = Test::MockObject->new();
		$mock_creature_type->set_always('level', 1);
		my $mock_creature = Test::MockObject->new();
		$mock_creature->set_always('type', $mock_creature_type);
		push @creatures, $mock_creature;
	}
	my $mock_cg = Test::MockObject->new();
	$mock_cg->set_bound('creatures', \@creatures);
	$mock_cg->set_true('land_id');
	$mock_cg->set_true('dungeon_grid_id');
	$mock_cg->set_true('update');
	$mock_cg->set_always('level', 1);

	my @characters;
	for (1..5) {
		my $mock_character = Test::MockObject->new();
		$mock_character->set_always('id', $_);
		$mock_character->set_always('character_name', "char$_");
		$mock_character->set_always('xp', 50);
		$mock_character->set_true('update');
		$mock_character->mock('character_effects', sub {return ()});
		$mock_character->set_false('is_dead');
		push @characters, $mock_character;
	}
	my $mock_party = Test::MockObject->new();
	$mock_party->set_bound('characters', \@characters);
	$mock_party->set_always('gold', 100);
	$mock_party->set_true('update');
	$mock_party->set_true('in_combat_with');
	
	my $mock_party_location = Test::MockObject->new();
	$mock_party_location->set_always('creature_threat', 5);
	$mock_party_location->set_always('update');
	
	my $mock_combat_log = Test::MockObject->new();
	$mock_combat_log->set_true('gold_found');
	$mock_combat_log->set_true('xp_awarded');
	$mock_combat_log->set_true('encounter_ended');
	
	my $battle = Test::MockObject->new();
    $battle->set_always('creature_group', $mock_cg);
    $battle->set_always('party', $mock_party);
    $battle->set_always('combat_log', $mock_combat_log);
    $battle->set_always('distribute_xp', {1 => 10, 2 => 10, 3 => 8, 4 => 10, 5 => 14});
    $battle->set_true('check_for_item_found');
    $battle->set_true('end_of_combat_cleanup');
    $battle->set_always('config', {xp_multiplier => 10});
    $battle->set_always('location', $mock_party_location);
    my $result = {};
    $battle->mock('result', sub { $result });
    
    $self->mock_dice;	
	$self->{roll_result} = 5;
	
	# WHEN
	RPG::Combat::Battle::finish($battle);
	
	# THEN
    is(defined $result->{awarded_xp}, 1, "Awarded xp returned"); 
	is($result->{gold}, 25, "Gold returned in result correctly");
	
	my @args;	
	
	is($mock_party->call_pos(2), 'in_combat_with', "in_combat_with set to new value");
	@args = $mock_party->call_args(2);
	is($args[1], undef, "No longer in combat");	
	
	is($mock_party->call_pos(4), 'gold', "Gold set to new value");
	@args = $mock_party->call_args(4);
	is($args[1], 125, "Gold set to correct value");
	
	$mock_party->called_ok('update', 'Party updated');
	
	is($mock_cg->call_pos(3), 'land_id', 'Creature group land id changed');
	is($mock_cg->call_pos(5), 'update', 'Creature group updated');
	
	is($mock_party_location->call_pos(2), 'creature_threat', "Create threat modified");
	@args = $mock_party_location->call_args(2);	
	is($args[1], 0, "Reduced by 5");
	
	$mock_party_location->called_ok('update', "Location updated");

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
				1 => 26,
				2 => 26,
				3 => 26,
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
				1 => 36,
				2 => 33,
				3 => 29,	
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

sub test_check_end_for_combat_cg_defeated : Tests(5) {
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
	$battle->set_always('opponents_of', $cg);
	$battle->set_list('opponents', $party, $cg);
	$battle->set_always('combat_log', $combat_log);
	$battle->mock('result', sub { $result } );	
	
	# WHEN
	RPG::Combat::Battle::check_end_for_combat($battle, $combatant);
	
	# THEN
	my ($method, $args) = $combat_log->next_call();
	is($method, 'outcome', "outcome set on combat log");
	is($args->[1], 'opp1_won', "outcome set correctly");

	($method, $args) = $combat_log->next_call(1);
	is($method, 'encounter_ended', "encounter_ended set on combat log");
	isa_ok($args->[1], 'DateTime', "encounter_ended set to a datetime");
	
	is($result->{combat_complete}, 1, "Combat complete set");   
}

sub test_check_end_for_combat_party_defeated : Tests(6) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, hit_points => 0 );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, );
    my $combatant = Test::MockObject->new();
    
    my $combat_log = Test::MockObject->new();
    $combat_log->set_true('outcome');
    $combat_log->set_true('encounter_ended');
    
    my $result = {};
        
	my $battle = Test::MockObject->new();
	$battle->set_always('opponents_of', $party);
	$battle->set_list('opponents', $party, $cg);
	$battle->set_always('combat_log', $combat_log);
	$battle->mock('result', sub { $result } );	
	
	# WHEN
	RPG::Combat::Battle::check_end_for_combat($battle, $combatant);
	
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


1;