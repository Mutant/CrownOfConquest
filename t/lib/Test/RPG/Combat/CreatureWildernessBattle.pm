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

use Storable qw(thaw);
use Data::Dumper;

sub startup : Tests(startup => 1) {
    use_ok 'RPG::Combat::CreatureWildernessBattle';
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
    is( ref $results, 'ARRAY', "Array returned" );
    isa_ok( $results->[0], "RPG::Schema::Creature", "opponent was a creature" );
    is( $results->[0]->creature_group_id, $cg->id, ".. from the correct cg" );
    ok( $results->[1] > 0, "Damage greater than 0" );
}

sub test_character_action_cast_spell : Tests(2) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );

    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    $character->party_id( $party->id );
    $character->last_combat_action('Cast');
    
    my $spell = $self->{schema}->resultset('Spell')->find(
        {
            spell_name => 'Energy Beam',
        }
    );
    
    my $mem_spell = $self->{schema}->resultset('Memorised_Spells')->create(
        {
            character_id      => $character->id,
            spell_id          => $spell->id,
            memorise_count    => 1,
            number_cast_today => 0,
        }
    );    
    
    $character->last_combat_param1($spell->id);
    
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
    
    my $creature = ($cg->creatures)[0];
    
    $character->last_combat_param2($creature->id);
    $character->update;

    $self->{config} = {
        creature_defence_base => 5,
        create_defence_factor_increment => 5,
        creature_attack_base => 5,
        create_attack_factor_increment => 5,        
    };

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
    is( ref $results, 'HASH', "Spell Results returned" );
    is($battle->combat_log->spells_cast, 1, "Number of spells cast incremented in combat log");
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

    isa_ok( $results->[0], "RPG::Schema::Character", "opponent was a character" );
    is( $results->[0]->party_id,                               $party->id, ".. from the correct party" );
    is( $results->[1],                                         1,          "Damage returned correctly" );
    is( $battle->session->{attack_count}{ $results->[0]->id }, 1,          "Session updated with attack count" );

    my ( $method, $args ) = $battle->next_call();

    is( $method, "attack", "Attack called" );
    isa_ok( $args->[1], "RPG::Schema::Creature", "First param passed to attack was a creature" );
    is( $args->[1]->id, $creature->id, "Correct creature passed" );
    isa_ok( $args->[2], "RPG::Schema::Character", "Second param passed to attack was a character" );
    is( $args->[2]->id, $results->[0]->id, "Correct character passed" );
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

sub test_check_for_flee_successful_flee : Tests(7) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
    $party->in_combat_with( $cg->id );
    $party->update;

    $party = Test::MockObject::Extends->new($party);
    $party->set_always( 'level', 10 );

    my $battle = RPG::Combat::CreatureWildernessBattle->new(
        schema             => $self->{schema},
        party              => $party,
        creature_group     => $cg,
        creatures_can_flee => 1,
        config             => { chance_creatures_flee_per_level_diff => 1 },
        log                => $self->{mock_logger},
    );

    my $combat_log = Test::MockObject->new();
    $combat_log->set_always( 'rounds', 3 );
    $combat_log->set_true('outcome');
    $combat_log->set_true('encounter_ended');
    $combat_log->set_true('update');

    my $land = Test::MockObject->new();
    $land->set_always( 'id', 1 );

    $battle = Test::MockObject::Extends->new($battle);
    $battle->set_always( 'combat_log',            $combat_log );
    $battle->set_always( 'get_sector_to_flee_to', $land );
    $battle->set_true('session');

    $self->mock_dice;
    undef $self->{rolls};
    $self->{roll_result} = 1;

    # WHEN
    my $result = $battle->check_for_flee();

    # THEN
    is_deeply( $result, { creatures_fled => 1 }, "Creatures fled" );

    $cg->discard_changes;
    is( $cg->land_id, 1, "Fled to correct land" );

    $party->discard_changes;
    is( $party->in_combat_with, undef, "party no longer in combat" );

    my ( $name, $args ) = $combat_log->next_call(3);
    is( $name,      "outcome",        "outcome of combat log set" );
    is( $args->[1], 'creatures_fled', "outcome set correctly" );

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

        $self->{session}{unsuccessful_flee_attempts} = $test_data->{previous_flee_attempts};

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

        $battle = Test::MockObject::Extends->new($battle);
        $battle->set_always( 'session', { unsuccessful_flee_attempts => $test_data->{previous_flee_attempts} } );

        $results{$test_name} = $battle->roll_flee_attempt();
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

sub test_execute_round_creature_group_wiped_out : Tests {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2  );
    my $cg    = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
    $cg = Test::MockObject::Extends->new($cg);
    $cg->set_always('number_alive', 0);

    $self->{config} = {
        attack_dice_roll => 10,
        defence_dice_roll => 10,  
        creature_defence_base => 5,
        create_defence_factor_increment => 5,
        creature_attack_base => 5,
        create_attack_factor_increment => 5,
        maximum_turns => 300,
        xp_multiplier => 10,
        chance_to_find_item => 0,
        prevalence_per_creature_level_to_find => 1,
    };

    my $battle = RPG::Combat::CreatureWildernessBattle->new(
        schema         => $self->{schema},
        party          => $party,
        creature_group => $cg,
        config         => $self->{config},
        log            => $self->{mock_logger},
    );
    $battle = Test::MockObject::Extends->new($battle);
    $battle->set_always('check_for_flee', undef);
    $battle->set_true('process_effects');
    
    # WHEN
    my $result = $battle->execute_round();
    
    # THEN
    is($result->{combat_complete}, 1, "Combat ended");
}

1;
