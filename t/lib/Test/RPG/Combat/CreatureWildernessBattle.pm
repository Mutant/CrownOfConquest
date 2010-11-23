use strict;
use warnings;

package Test::RPG::Combat::CreatureWildernessBattle;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::MockObject::Extends;
use Test::More;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::CreatureGroup;
use Test::RPG::Builder::Item;
use Test::RPG::Builder::Day;
use Test::RPG::Builder::Item_Type;
use Test::RPG::Builder::Land;
use Test::RPG::Builder::Town;

use Storable qw(thaw);
use Data::Dumper;

use Carp qw(cluck);

sub startup : Tests(startup => 2) {
	my $self = shift;

	use_ok 'RPG::Combat::CreatureWildernessBattle';
	use_ok 'RPG::Template';
}

sub setup : Tests(setup) {
	my $self = shift;

	Test::RPG::Builder::Day->build_day( $self->{schema} );

}

sub test_process_effects_one_char_effect : Tests(2) {
	my $self = shift;

	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );

	my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
	$character->party_id( $party->id );
	$character->update;

	my $effect = $self->{schema}->resultset('Effect')->create(
		{
			effect_name => 'Foo',
			time_left   => 2,
			combat      => 1,
		},
	);

	$self->{schema}->resultset('Character_Effect')->create(
		{
			character_id => $character->id,
			effect_id    => $effect->id,
		}
	);

	my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		schema         => $self->{schema},
		party          => $party,
		creature_group => $cg,
		log            => $self->{mock_logger},
	);

	# WHEN
	$battle->process_effects;

	# THEN
	my @effects = $character->character_effects;
	is( scalar @effects,                1, "Character still has one effect" );
	is( $effects[0]->effect->time_left, 1, "Time left has been reduced" );
}

sub test_process_effects_one_creature_effect : Tests(2) {
	my $self = shift;

	# GIVEN
	my $party    = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $cg       = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
	my $creature = ( $cg->creatures )[0];

	my $effect = $self->{schema}->resultset('Effect')->create(
		{
			effect_name   => 'Foo',
			time_left     => 1,
			combat        => 1,
			modifier      => 2,
			modified_stat => 'attack_frequency',
		},
	);

	$self->{schema}->resultset('Creature_Effect')->create(
		{
			creature_id => $creature->id,
			effect_id   => $effect->id,
		}
	);

	$cg = $self->{schema}->resultset('CreatureGroup')->get_by_id( $cg->id );

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		schema         => $self->{schema},
		party          => $party,
		creature_group => $cg,
		log            => $self->{mock_logger},
	);

	# WHEN
	$battle->process_effects;

	# THEN
	my @effects = $creature->creature_effects;
	is( scalar @effects, 0, "Effect has been deleted" );

	($creature) = grep { $_->id == $creature->id } $battle->creature_group->creatures;
	is( $creature->number_of_attacks, 1, "Number of attacks back to normal" );
}

sub test_character_action_no_target : Tests(4) {
	my $self = shift;

	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );

	my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
	$character->party_id( $party->id );
	$character->last_combat_action('Attack');
	$character->update;

	my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		schema         => $self->{schema},
		party          => $party,
		creature_group => $cg,
		log            => $self->{mock_logger},
	);

	$battle = Test::MockObject::Extends->new($battle);
	$battle->set_always( 'attack',                 1 );
	$battle->set_always( 'check_character_attack', 1 );

	# WHEN
	my $results = $battle->character_action($character);

	# THEN
	isa_ok( $results,           'RPG::Combat::ActionResult', "Action Result returned" );
	isa_ok( $results->defender, "RPG::Schema::Creature",     "opponent was a creature" );
	is( $results->defender->creature_group_id, $cg->id, ".. from the correct cg" );
	ok( $results->damage > 0, "Damage greater than 0" );
}

sub test_character_action_cast_spell_on_opponent : Tests(2) {
	my $self = shift;

	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );

	my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
	$character->party_id( $party->id );
	$character->last_combat_action('Cast');

	my $spell = $self->{schema}->resultset('Spell')->find( { spell_name => 'Energy Beam', } );

	my $mem_spell = $self->{schema}->resultset('Memorised_Spells')->create(
		{
			character_id      => $character->id,
			spell_id          => $spell->id,
			memorise_count    => 1,
			number_cast_today => 0,
		}
	);

	$character->last_combat_param1( $spell->id );

	my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );

	my $creature = ( $cg->creatures )[0];

	$character->last_combat_param2( $creature->id );
	$character->update;

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		schema         => $self->{schema},
		party          => $party,
		creature_group => $cg,
		log            => $self->{mock_logger},
	);

	$battle = Test::MockObject::Extends->new($battle);

	# WHEN
	my $results = $battle->character_action($character);

	# THEN
	isa_ok( $results, 'RPG::Combat::SpellActionResult', "Spell Results returned" );
	is( $battle->combat_log->spells_cast, 1, "Number of spells cast incremented in combat log" );
}

sub test_character_action_cast_spell_on_opponent_who_is_killed : Tests(4) {
	my $self = shift;

	# GIVEN
	$self->mock_dice;
	$self->clear_dice_data;

	$self->{roll_result} = 6;

	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );

	my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
	$character->party_id( $party->id );
	$character->last_combat_action('Cast');

	my $spell = $self->{schema}->resultset('Spell')->find( { spell_name => 'Energy Beam', } );

	my $mem_spell = $self->{schema}->resultset('Memorised_Spells')->create(
		{
			character_id      => $character->id,
			spell_id          => $spell->id,
			memorise_count    => 1,
			number_cast_today => 0,
		}
	);

	$character->last_combat_param1( $spell->id );

	my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );

	my $creature = ( $cg->creatures )[0];
	$creature->hit_points_current(6);
	$creature->update;

	$character->last_combat_param2( $creature->id );
	$character->update;

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		schema         => $self->{schema},
		party          => $party,
		creature_group => $cg,
		log            => $self->{mock_logger},
	);

	# WHEN
	my $results = $battle->character_action($character);

	# THEN
	isa_ok( $results, 'RPG::Combat::SpellActionResult', "Spell Results returned" );
	is( $results->defender_killed,        1, "Defender marked as killed" );
	is( $results->damage,                 6, "Damage recorded" );
	is( $battle->combat_log->spells_cast, 1, "Number of spells cast incremented in combat log" );

	$self->unmock_dice;
}

sub test_character_action_cast_spell_on_party_member : Tests(3) {
	my $self = shift;

	# GIVEN
	$self->mock_dice;
	$self->clear_dice_data;

	$self->{roll_result} = 6;

	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );

	my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
	$character->party_id( $party->id );
	$character->last_combat_action('Cast');

	my $target = Test::RPG::Builder::Character->build_character( $self->{schema} );
	$target->party_id( $party->id );
	$target->max_hit_points(10);
	$target->hit_points(5);
	$target->update;

	my $spell = $self->{schema}->resultset('Spell')->find( { spell_name => 'Heal', } );

	my $mem_spell = $self->{schema}->resultset('Memorised_Spells')->create(
		{
			character_id      => $character->id,
			spell_id          => $spell->id,
			memorise_count    => 1,
			number_cast_today => 0,
		}
	);

	$character->last_combat_param1( $spell->id );
	$character->last_combat_param2( $target->id );
	$character->update;

	my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		schema         => $self->{schema},
		party          => $party,
		creature_group => $cg,
		log            => $self->{mock_logger},
	);

	$battle = Test::MockObject::Extends->new($battle);

	# WHEN
	my $results = $battle->character_action($character);

	# THEN
	isa_ok( $results, 'RPG::Combat::SpellActionResult', "Spell Results returned" );
	is( $battle->combat_log->spells_cast, 1, "Number of spells cast incremented in combat log" );
	$target->discard_changes;
	ok( $target->hit_points > 5, "Hit points have increased" );

	$self->unmock_dice;
}

sub test_character_action_use_item : Tests(5) {
	my $self = shift;

	# GIVEN
	$self->mock_dice;
	$self->clear_dice_data;

	$self->{roll_result} = 6;

	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );

	my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
	$character->party_id( $party->id );
	$character->last_combat_action('Use');

	my $target = Test::RPG::Builder::Character->build_character( $self->{schema} );
	$target->party_id( $party->id );
	$target->max_hit_points(10);
	$target->hit_points(5);
	$target->update;

	my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $character->id, enchantments => ['spell_casts_per_day'] );
	$item->variable_row( 'Spell',         'Heal' );
	$item->variable_row( 'Casts Per Day', 2 );

	$character->last_combat_param1( $item->variable_row('Spell')->item_enchantment_id );
	$character->last_combat_param2( $target->id );
	$character->update;

	my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		schema         => $self->{schema},
		party          => $party,
		creature_group => $cg,
		log            => $self->{mock_logger},
	);

	$battle = Test::MockObject::Extends->new($battle);

	# WHEN
	my $result = $battle->character_action($character);

	# THEN
	isa_ok( $result, 'RPG::Combat::SpellActionResult', "Spell Results returned" );
	is( $result->damage, 6, "Heal amount recorded in action result" );

	is( $battle->combat_log->spells_cast, 1, "Number of spells cast incremented in combat log" );
	$target->discard_changes;
	is( $target->hit_points, 10, "Target's hit points have increased" );

	$item->discard_changes;
	is( $item->variable('Casts Per Day'), 1, "Item's casts per day reduced" );

	$self->unmock_dice;
}

sub test_creature_action_basic : Tests(9) {
	my $self = shift;

	# GIVEN
	my $party    = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $cg       = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
	my $creature = ( $cg->creatures )[0];

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		schema         => $self->{schema},
		party          => $party,
		creature_group => $cg,
		config         => { front_rank_attack_chance => 1 },
		log            => $self->{mock_logger},
	);

	$battle = Test::MockObject::Extends->new($battle);
	$battle->set_always( 'attack', 1 );

	$self->{roll_result} = 4;

	# WHEN
	my $results = $battle->creature_action($creature);

	# THEN
	isa_ok( $results->defender, "RPG::Schema::Character", "opponent was a character" );
	is( $results->defender->party_id,                               $party->id, ".. from the correct party" );
	is( $results->damage,                                           1,          "Damage returned correctly" );
	is( $battle->session->{attack_count}{ $results->defender->id }, 1,          "Session updated with attack count" );

	my ( $method, $args ) = $battle->next_call();

	is( $method, "attack", "Attack called" );
	isa_ok( $args->[1], "RPG::Schema::Creature", "First param passed to attack was a creature" );
	is( $args->[1]->id, $creature->id, "Correct creature passed" );
	isa_ok( $args->[2], "RPG::Schema::Character", "Second param passed to attack was a character" );
	is( $args->[2]->id, $results->defender->id, "Correct character passed" );
}

sub test_attack_character_attack_basic : Tests(1) {
	my $self = shift;

	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );

	my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id );
	my $creature = ( $cg->creatures )[0];

	my $config = {
		attack_dice_roll  => 1,
		defence_dice_roll => 1,
	};

	my $attack_factors = {
		character => { $character->id => { af => 1, dam => 5 } },
		creature  => { $creature->id  => { df => 1 } },
	};

	my $mock_dice = $self->mock_dice;
	$self->{rolls} = [ 1, 2, 5 ];

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		schema         => $self->{schema},
		party          => $party,
		creature_group => $cg,
		config         => $config,
		log            => $self->{mock_logger},
	);

	$battle = Test::MockObject::Extends->new($battle);
	$battle->set_always( 'check_character_attack', undef );
	$battle->set_always( 'combat_factors',         $attack_factors );

	# WHEN
	my $damage = $battle->attack( $character, $creature );

	# THEN
	is( $damage, 5, "Attack hit, did 5 damage" );

}

sub test_session_updated_when_object_destroyed : Tests(1) {
	my $self = shift;

	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		schema         => $self->{schema},
		party          => $party,
		creature_group => $cg,
		log            => $self->{mock_logger},
	);

	# WHEN
	$battle->session->{foo} = 'bar';
	undef $battle;

	# THEN
	my $combat_log = $self->{schema}->resultset('Combat_Log')->find(
		{
			opponent_1_id => $party->id,
			opponent_2_id => $cg->id,
		},
	);

	my $session = thaw $combat_log->session;

	is( $session->{foo}, 'bar', "Session saved to DB" );

}

sub test_check_for_flee_creatures_cant_flee : Tests(1) {
	my $self = shift;

	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );

	$self->{config}{online_threshold} = 10;

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		schema             => $self->{schema},
		party              => $party,
		creature_group     => $cg,
		creatures_can_flee => 0,
		log                => $self->{mock_logger},
	);

	# WHEN
	my $result = $battle->check_for_flee();

	# THEN
	is( $result, undef, "No fleeing, since creatures not allowed to flee" );

}

sub test_check_for_flee_successful_flee : Tests(9) {
	my $self = shift;

	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $cg    = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
	my $cret  = ( $cg->creatures )[0];

	$party->in_combat_with( $cg->id );
	$party->update;

	$party = Test::MockObject::Extends->new($party);
	$party->set_always( 'level', 10 );

	$self->{config}{online_threshold} = 10;

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		schema             => $self->{schema},
		party              => $party,
		creature_group     => $cg,
		creatures_can_flee => 1,
		config             => { chance_creatures_flee_per_level_diff => 1, xp_multiplier => 10 },
		log                => $self->{mock_logger},
	);

	my $combat_log = Test::MockObject->new();
	$combat_log->set_always( 'rounds', 2 );
	$combat_log->set_true('outcome');
	$combat_log->set_true('encounter_ended');
	$combat_log->set_true('update');
	$combat_log->set_true('xp_awarded');
	$combat_log->set_true('session');

	my $land = Test::MockObject->new();
	$land->set_always( 'id', 1 );
	$land->set_isa('RPG::Schema::Land');

	$battle = Test::MockObject::Extends->new($battle);
	$battle->set_always( 'combat_log',            $combat_log );
	$battle->set_always( 'get_sector_to_flee_to', $land );
	$battle->set_always( 'session', { killed => { 'creature' => [ $cret->id ] }, } );

	$self->mock_dice;
	undef $self->{rolls};
	$self->{roll_result} = 1;

	# WHEN
	my $fled = $battle->check_for_flee();

	# THEN
	is( $fled, 1, "Someone fled" );
	is_deeply( $battle->result->{creatures_fled}, 1, "Creatures fled" );

	$cg->discard_changes;
	is( $cg->land_id, 1, "Fled to correct land" );

	my ( $name, $args ) = $combat_log->next_call(3);
	is( $name, "xp_awarded", "xp awarded in combat log set" );
	ok( $args->[1] > 0, "some xp awarded" ) || diag( "xp: " . $args->[1] );

	( $name, $args ) = $combat_log->next_call();
	is( $name,      "outcome",   "outcome of combat log set" );
	is( $args->[1], 'opp2_fled', "outcome set correctly" );

	( $name, $args ) = $combat_log->next_call();
	is( $name, "encounter_ended", "encounter ended of combat log set" );
	isa_ok( $args->[1], 'DateTime', "encounted ended set correctly" );

}

sub test_roll_flee_attempt : Tests(5) {
	my $self = shift;

	# GIVEN
	$self->{config}{base_flee_chance}             = 50;
	$self->{config}{flee_chance_level_modifier}   = 5;
	$self->{config}{flee_chance_attempt_modifier} = 5;
	$self->{config}{flee_chance_low_level_bonus}  = 10;

	my %tests = (
		basic_test_success => {
			cg_level               => 2,
			party_level            => 2,
			roll                   => 50,
			expected_result        => 1,
			previous_flee_attempts => 0,
		},
		basic_test_fail => {
			cg_level               => 2,
			party_level            => 2,
			roll                   => 51,
			expected_result        => 0,
			previous_flee_attempts => 0,
		},
		party_low_level => {
			cg_level               => 6,
			party_level            => 2,
			roll                   => 70,
			expected_result        => 1,
			previous_flee_attempts => 0,
		},
		previous_attempts => {
			cg_level               => 4,
			party_level            => 2,
			roll                   => 70,
			expected_result        => 1,
			previous_flee_attempts => 2,
		},
		level_1_party => {
			cg_level               => 1,
			party_level            => 1,
			roll                   => 60,
			expected_result        => 1,
			previous_flee_attempts => 0,
		},
	);

	$self->mock_dice;

	# WHEN
	my %results;
	while ( my ( $test_name, $test_data ) = each %tests ) {
		my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, creature_level => $test_data->{cg_level} );

		$self->{roll_result} = $test_data->{roll};

		my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_level => $test_data->{party_level}, character_count => 2 );
		$party->in_combat_with( $cg->id );
		$party->update;

		my $battle = RPG::Combat::CreatureWildernessBattle->new(
			schema             => $self->{schema},
			party              => $party,
			creature_group     => $cg,
			creatures_can_flee => 1,
			config             => $self->{config},
			log                => $self->{mock_logger},
		);

		$battle->combat_log->opponent_1_flee_attempts( $test_data->{previous_flee_attempts} );

		$battle = Test::MockObject::Extends->new($battle);
		$battle->set_always( 'session', { unsuccessful_flee_attempts => $test_data->{previous_flee_attempts} } );

		$results{$test_name} = $battle->roll_flee_attempt( $party, $cg, 1 );
	}

	# THEN
	while ( my ( $test_name, $test_data ) = each %tests ) {
		is( $results{$test_name}, $test_data->{expected_result}, "Flee result as expected for test: $test_name" );
	}
}

sub test_build_character_weapons : Tests(3) {
	my $self = shift;

	# GIVEN
	my $party     = Test::RPG::Builder::Party->build_party( $self->{schema} );
	my $cg        = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
	my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
	$character->party_id( $party->id );
	$character->update;

	my $item = Test::RPG::Builder::Item->build_item(
		$self->{schema},
		variables => [
			{
				item_variable_name  => 'Durability',
				item_variable_value => 5,
			}
		],
		attributes => [
			{
				item_attribute_name  => 'Attack Factor',
				item_attribute_value => 5,
			},
			{
				item_attribute_name  => 'Damage',
				item_attribute_value => 5,
			}
		],
		super_category_name => 'Weapon',
	);
	$item->character_id( $character->id );
	$item->update;

	# WHEN
	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		schema         => $self->{schema},
		party          => $party,
		creature_group => $cg,
		config         => {},
		log            => $self->{mock_logger},
	);

	# THEN
	is( $battle->character_weapons->{ $character->id }{id},         $item->id, "Item id saved in session" );
	is( $battle->character_weapons->{ $character->id }{durability}, 5,         "Item durability saved in session" );
	is( $battle->character_weapons->{ $character->id }{ammunition}, undef,     "No ammo" );

}

sub test_execute_round_creature_killed : Tests(9) {
	my $self = shift;

	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 1 );
	my $char  = ( $party->characters )[0];
	my $cg    = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, creature_count => 1 );
	my $cret  = ( $cg->creatures )[0];

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		schema         => $self->{schema},
		party          => $party,
		creature_group => $cg,
		config         => $self->{config},
		log            => $self->{mock_logger},
	);
	$battle = Test::MockObject::Extends->new($battle);
	$battle->set_always( 'check_for_flee', undef );
	$battle->set_true('process_effects');

	my $char_action_result = RPG::Combat::ActionResult->new(
		{
			attacker        => $char,
			defender        => $cret,
			defender_killed => 1,
			damage          => 1,
		}
	);
	$battle->set_always( 'character_action', $char_action_result );

	my $cret_action_result = RPG::Combat::ActionResult->new(
		{
			attacker        => $cret,
			defender        => $char,
			defender_killed => 0,
			damage          => 2,
		}
	);
	$battle->set_always( 'creature_action', $cret_action_result );

	$battle->mock( 'get_combatant_list', sub { ( $cret, $char ) } );

	# WHEN
	my $result = $battle->execute_round();

	# THEN
	is( $result->{combat_complete},                       undef,     "Combat not ended" );
	is( scalar @{ $result->{messages} },                  2,         "2 Combat messages returned" );
	is( scalar @{ $battle->session->{killed}{creature} }, 1,         "One creature recorded as killed" );
	is( $battle->session->{killed}{creature}[0],          $cret->id, "Correct creature recorded as killed" );

	is( $battle->session->{damage_done}{ $char->id }, 1, "Damage recorded" );

	undef $battle;    # Force combat log to be written

	my $combat_log = $self->{schema}->resultset('Combat_Log')->search->first;

	is( $combat_log->opponent_2_deaths,       1, "Creature death recorded in combat log" );
	is( $combat_log->total_opponent_1_damage, 1, "Char Damage recorded in combat log" );

	is( $combat_log->opponent_1_deaths,       0, "No char deaths recorded in combat log" );
	is( $combat_log->total_opponent_2_damage, 2, "Cret Damage recorded in combat log" );
}

sub test_execute_round_creature_group_wiped_out : Tests(1) {
	my $self = shift;

	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
	$cg = Test::MockObject::Extends->new($cg);
	$cg->set_always( 'number_alive', 0 );

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		schema         => $self->{schema},
		party          => $party,
		creature_group => $cg,
		config         => $self->{config},
		log            => $self->{mock_logger},
	);
	$battle = Test::MockObject::Extends->new($battle);
	$battle->set_always( 'check_for_flee', undef );
	$battle->set_true('process_effects');

	# WHEN
	my $result = $battle->execute_round();

	# THEN
	is( $result->{combat_complete}, 1, "Combat ended" );
}

sub test_execute_round_messages_recorded_in_db : Tests(4) {
	my $self = shift;

	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, );
	my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
	$cg = Test::MockObject::Extends->new($cg);
	$cg->set_always( 'number_alive', 0 );

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		schema         => $self->{schema},
		party          => $party,
		creature_group => $cg,
		config         => $self->{config},
		log            => $self->{mock_logger},
	);
	$battle = Test::MockObject::Extends->new($battle);
	$battle->set_always( 'check_for_flee', undef );
	$battle->set_true('process_effects');

	# WHEN
	my $result = $battle->execute_round();

	# THEN
	is( $result->{combat_complete}, 1, "Combat ended" );

	my $combat_log_message = $self->{schema}->resultset('Combat_Log_Messages')->search->first;

	is( $combat_log_message->round,           1, "Round number recorded" );
	is( $combat_log_message->opponent_number, 1, "Opp number set correctly" );
	is( defined $combat_log_message->message, 1, "Message set" );
}

sub test_execute_round_party_flees_successfully : Tests(5) {
	my $self = shift;

	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
	$cg = Test::MockObject::Extends->new($cg);
	$cg->set_always( 'number_alive', 0 );

	my $home = $ENV{RPG_HOME};
	$self->{config} = {
		attack_dice_roll                      => 10,
		defence_dice_roll                     => 10,
		creature_defence_base                 => 5,
		create_defence_factor_increment       => 5,
		creature_attack_base                  => 5,
		create_attack_factor_increment        => 5,
		maximum_turns                         => 300,
		xp_multiplier                         => 10,
		chance_to_find_item                   => 0,
		prevalence_per_creature_level_to_find => 1,
		nearby_town_range                     => 5,
		online_threshold                      => 10,
		combat_rounds_per_turn                => 3,
		home                                  => $home,
	};

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		schema             => $self->{schema},
		party              => $party,
		creature_group     => $cg,
		config             => $self->{config},
		log                => $self->{mock_logger},
		party_flee_attempt => 1,
	);
	$battle = Test::MockObject::Extends->new($battle);
	$battle->set_always( 'party_flee', 1 );
	$battle->set_true('process_effects');

	# WHEN
	my $result = $battle->execute_round();

	# THEN
	is( $result->{combat_complete}, 1, "Combat ended" );
	is( $result->{party_fled},      1, "Party fled recorded in DB" );

	my $combat_log_message = $self->{schema}->resultset('Combat_Log_Messages')->search->first;

	is( $combat_log_message->round,           1, "Round number recorded" );
	is( $combat_log_message->opponent_number, 1, "Opp number set correctly" );
	like( $combat_log_message->message, qr/You fled the battle!/, "Flee message set" );
}

sub test_finish : Tests(6) {
	my $self = shift;

	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
	$party->in_combat_with( $cg->id );
	$party->update;

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		schema         => $self->{schema},
		party          => $party,
		creature_group => $cg,
		config         => $self->{config},
		log            => $self->{mock_logger},
	);

	$self->{config}{nearby_town_range} = 5;

	$self->mock_dice;
	$self->{roll_result} = 10;

	# WHEN
	$battle->finish($cg);

	# THEN
	is( defined $battle->result->{awarded_xp}, 1,  "Awarded xp returned" );
	is( $battle->result->{gold},               30, "Gold returned in result correctly" );

	$party->discard_changes;
	is( $party->gold,           130,   "Gold added to party" );

	$cg->discard_changes;
	is( $cg->land_id, undef, "CG no longer in land" );

	is( defined $battle->combat_log->encounter_ended, 1, "Combat log records combat ended" );
}

sub test_end_of_combat_cleanup_creates_town_history : Tests(3) {
	my $self = shift;

	# GIVEN
	my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
	my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $land[0]->id );

	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, land_id => $land[8]->id );
	my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, land_id => $land[8]->id );
	$party->in_combat_with( $cg->id );
	$party->update;

	$self->{config}{nearby_town_range} = 5;

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		schema         => $self->{schema},
		party          => $party,
		creature_group => $cg,
		config         => $self->{config},
		log            => $self->{mock_logger},
	);

	my $mock_template = Test::MockObject::Extra->new();
	$mock_template->fake_module( 'RPG::Template', process => sub { 'combat_log_message' }, );

	$self->mock_dice;
	$self->{roll_result} = 10;

	# WHEN
	$battle->end_of_combat_cleanup();

	# THEN
	my @history = $self->{schema}->resultset('Town_History')->search( town_id => $town->id, );

	is( scalar @history, 1, "One history item recorded" );
	is( $history[0]->message, 'combat_log_message', "Message set correctly" );
	is ($history[0]->type, 'news', "Message type set correctly");

	my $party_town = $self->{schema}->resultset('Party_Town')->find(
		{
			party_id => $party->id,
			town_id  => $town->id,
		}
	);

	$mock_template->unfake_module();
	require RPG::Template;
	$self->unmock_dice;
}

sub test_check_for_item_found_correct_prevalence_used : Tests(5) {
	my $self = shift;

	# GIVEN
	my $party     = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 1 );
	my $character = ( $party->characters )[0];
	my $cg        = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, creature_level => 1 );

	$self->{config}{chance_to_find_item}                   = 10;
	$self->{config}{prevalence_per_creature_level_to_find} = 10;

	my $item_type_1 = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema}, prevalence => 90 );
	my $item_type_2 = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema}, prevalence => 89 );

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		schema         => $self->{schema},
		party          => $party,
		creature_group => $cg,
		config         => $self->{config},
		log            => $self->{mock_logger},
	);

	$self->mock_dice;
	$self->{roll_result} = 1;

	# WHEN
	$battle->check_for_item_found( [ $party->characters ], $cg->level );

	# THEN
	my @found_items = @{ $battle->result->{found_items} };
	is( scalar @found_items, 1, "One item found" );
	isa_ok( $found_items[0]->{finder}, 'RPG::Schema::Character', "Character set as finder" );
	is( $found_items[0]->{finder}->id, $character->id, "Correct character is finder" );
	isa_ok( $found_items[0]->{item}, 'RPG::Schema::Items', "Item set in result" );
	is( $found_items[0]->{item}->item_type_id, $item_type_1->id, "Item is of correct type" );

}

sub test_oppoent_number_of_being : Tests(2) {
	my $self = shift;

	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 1, party_id => 1, );
	my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, creature_count => 1, creature_group_id => 1 );

	my $cret = ( $cg->creatures )[0];
	my $char = ( $party->characters )[0];

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		schema         => $self->{schema},
		party          => $party,
		creature_group => $cg,
		config         => $self->{config},
		log            => $self->{mock_logger},
	);

	# WHEN
	my $party_opp_number = $battle->opponent_number_of_being($char);
	my $cg_opp_number    = $battle->opponent_number_of_being($cret);

	# THEN
	is( $party_opp_number, 1, "Party opp number correct" );
	is( $cg_opp_number,    2, "CG opp number correct" );

}

sub test_oppoent_number_of_group : Tests(2) {
	my $self = shift;

	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 1, party_id => 1, );
	my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, creature_count => 1, creature_group_id => 1 );

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		schema         => $self->{schema},
		party          => $party,
		creature_group => $cg,
		config         => $self->{config},
		log            => $self->{mock_logger},
	);

	# WHEN
	my $party_opp_number = $battle->opponent_number_of_group($party);
	my $cg_opp_number    = $battle->opponent_number_of_group($cg);

	# THEN
	is( $party_opp_number, 1, "Party opp number correct" );
	is( $cg_opp_number,    2, "CG opp number correct" );
}

sub test_combatants_always_gives_same_objects : Tests(3) {
	my $self = shift;

	# GIVEN	
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 1, );
	my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, creature_count => 1,);

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		schema         => $self->{schema},
		party          => $party,
		creature_group => $cg,
		config         => $self->{config},
		log            => $self->{mock_logger},
	);

	# WHEN
	my @combatants1 = $battle->combatants;
	my @combatants2 = $battle->combatants;
	
	# THEN
	is(scalar @combatants1, scalar @combatants2, "Combatants lists the same size");
	is($combatants1[0], $combatants2[0], "Character is the same object");
	is($combatants1[1], $combatants2[1], "Creature is the same object");
	
}

1;

