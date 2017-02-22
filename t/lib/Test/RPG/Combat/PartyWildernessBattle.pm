use strict;
use warnings;

package Test::RPG::Combat::PartyWildernessBattle;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::MockObject::Extends;
use Test::More;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::CreatureGroup;
use Test::RPG::Builder::Party_Battle;
use Test::RPG::Builder::Day;
use Test::RPG::Builder::Garrison;
use Test::RPG::Builder::Land;
use Test::RPG::Builder::Town;

sub startup : Tests(startup => 1) {
    use_ok 'RPG::Combat::PartyWildernessBattle';
}

sub setup : Tests(setup) {
    my $self = shift;

    Test::RPG::Builder::Day->build_day( $self->{schema} );
}

sub test_opponent_of : Tests(2) {
    my $self = shift;

    # GIVEN
    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );

    my $battle_record = Test::RPG::Builder::Party_Battle->build_battle(
        $self->{schema},
        party_1 => $party1,
        party_2 => $party2,
    );

    my $character = ( $party1->characters )[0];

    my $battle = RPG::Combat::PartyWildernessBattle->new(
        schema        => $self->{schema},
        party_1       => $party1,
        party_2       => $party2,
        log           => $self->{mock_logger},
        battle_record => $battle_record,
    );

    # WHEN
    my $opp_party = $battle->opponents_of($character);

    # THEN
    isa_ok( $opp_party, 'RPG::Schema::Party', "Party object returned" );
    is( $opp_party->id, $party2->id, "Correct opponent party returned" );

}

sub test_finish : Tests(4) {
    my $self = shift;

    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );

    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, land_id => $land[0]->id );
    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, land_id => $party1->land_id );

    my $battle_record = Test::RPG::Builder::Party_Battle->build_battle(
        $self->{schema},
        party_1 => $party1,
        party_2 => $party2,
    );

    $self->{config}{nearby_town_range}       = 5;
    $self->{config}{xp_multiplier_character} = 10;

    my $battle = RPG::Combat::PartyWildernessBattle->new(
        schema        => $self->{schema},
        party_1       => $party1,
        party_2       => $party2,
        log           => $self->{mock_logger},
        battle_record => $battle_record,
        config        => $self->{config},
    );

    $self->mock_dice;
    $self->{roll_result} = 5;

    # WHEN
    $battle->finish($party1);

    # THEN
    $party2->discard_changes;
    is( $party2->gold, 110, "Gold added to party 2" );

    $battle_record->discard_changes;
    is( defined $battle_record->complete, 1, "Battle record marked as complete" );

    is( $battle->result->{gold}, 10, "Gold found in result" );
}

sub test_party_flee : Tests(5) {
    my $self = shift;

    # GIVEN
    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );

    my $battle_record = Test::RPG::Builder::Party_Battle->build_battle(
        $self->{schema},
        party_1 => $party1,
        party_2 => $party2,
    );

    my $battle = RPG::Combat::PartyWildernessBattle->new(
        schema               => $self->{schema},
        party_1              => $party1,
        party_2              => $party2,
        log                  => $self->{mock_logger},
        battle_record        => $battle_record,
        party_2_flee_attempt => 1,
    );

    $self->{config}{maximum_turns} = 100;

    my $land = Test::MockObject->new();
    $land->set_always( 'id', 999 );
    $land->set_isa('RPG::Schema::Land');
    $land->set_always( 'movement_cost', 1 );
    $land->set_always( 'x',             1 );
    $land->set_always( 'y',             1 );

    $battle = Test::MockObject::Extends->new($battle);
    $battle->set_always( 'get_sector_to_flee_to', $land );
    $battle->set_true('roll_flee_attempt');

    # WHEN
    my $flee_result = $battle->check_for_flee();

    # THEN
    is( $flee_result,                  1, "Flee successful" );
    is( $battle->result->{party_fled}, 1, "Flee result successful" );

    $party2->discard_changes;
    is( $party2->land_id, 999, "Land id updated" );

    is( $battle->combat_log->outcome, 'opp2_fled', "Combat log outcome set correctly" );
    is( defined $battle->combat_log->encounter_ended, 1, "Combat log encounter ended set" );
}

sub test_offline_party_flee : Tests(6) {
    my $self = shift;

    # GIVEN
    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );

    my $char = ( $party1->characters )[0];

    my $battle_record = Test::RPG::Builder::Party_Battle->build_battle(
        $self->{schema},
        party_1 => $party1,
        party_2 => $party2,
    );

    my $battle = RPG::Combat::PartyWildernessBattle->new(
        schema        => $self->{schema},
        party_1       => $party1,
        party_2       => $party2,
        log           => $self->{mock_logger},
        battle_record => $battle_record,
        config        => { xp_multiplier_character => 10 },
    );

    $party1 = Test::MockObject::Extends->new($party1);
    $party1->set_false('is_online');
    $party1->set_true('is_over_flee_threshold');
    $party1->set_true('does_role');

    $self->{config}{maximum_turns} = 100;

    my $land = Test::MockObject->new();
    $land->set_always( 'id', 999 );
    $land->set_isa('RPG::Schema::Land');
    $land->set_always( 'movement_cost', 1 );
    $land->set_always( 'x',             1 );
    $land->set_always( 'y',             1 );

    $battle = Test::MockObject::Extends->new($battle);
    $battle->set_always( 'get_sector_to_flee_to', $land );
    $battle->set_true('roll_flee_attempt');
    $battle->set_always( 'session', { killed => { 'character' => [ $char->id ] }, } );

    # WHEN
    my $flee_result = $battle->check_for_flee();

    # THEN
    is( $flee_result,                          1, "Flee successful" );
    is( $battle->result->{offline_party_fled}, 1, "Flee result successful" );

    $party1->discard_changes;
    is( $party1->land_id, 999, "Land id updated" );

    is( $battle->combat_log->outcome, 'opp1_fled', "Combat log outcome set correctly" );
    is( defined $battle->combat_log->encounter_ended, 1, "Combat log encounter ended set" );

    ok( $battle->combat_log->xp_awarded > 0, "Xp awarded" );
}

sub test_characters_in_garrison_not_included_in_defenders : Tests(3) {
    my $self = shift;

    # GIVEN
    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party1->id );

    my $char1 = ( $party1->characters )[0];
    $char1->garrison_id( $garrison->id );
    $char1->update;

    my $char2 = ( $party1->characters )[1];

    my $char3 = ( $party2->characters )[0];
    $char3->last_combat_action('Attack');
    $char3->update;

    my $battle_record = Test::RPG::Builder::Party_Battle->build_battle(
        $self->{schema},
        party_1 => $party1,
        party_2 => $party2,
    );

    my $battle = RPG::Combat::PartyWildernessBattle->new(
        schema        => $self->{schema},
        party_1       => $party1,
        party_2       => $party2,
        log           => $self->{mock_logger},
        battle_record => $battle_record,
    );

    $battle = Test::MockObject::Extends->new($battle);
    $battle->set_always( 'attack', 1 );

    # WHEN
    my $action_result = $battle->character_action($char3);

    # THEN
    isa_ok( $action_result, 'RPG::Combat::ActionResult', "Action result object returned" );
    is( $action_result->attacker->id, $char3->id, "Correct attacker" );
    is( $action_result->defender->id, $char2->id, "Correct defender" );
}

sub test_characters_in_garrison_not_included_in_attackers : Tests(3) {
    my $self = shift;

    # GIVEN
    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 1 );
    my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party1->id );

    my $char1 = ( $party1->characters )[0];
    $char1->garrison_id( $garrison->id );
    $char1->last_combat_action('Attack');
    $char1->update;

    my $char2 = ( $party1->characters )[1];
    $char2->last_combat_action('Defend');
    $char2->update;

    my $char3 = ( $party2->characters )[0];
    $char3->last_combat_action('Attack');
    $char3->update;

    my $battle_record = Test::RPG::Builder::Party_Battle->build_battle(
        $self->{schema},
        party_1 => $party1,
        party_2 => $party2,
    );

    my $battle = RPG::Combat::PartyWildernessBattle->new(
        schema        => $self->{schema},
        party_1       => $party1,
        party_2       => $party2,
        log           => $self->{mock_logger},
        battle_record => $battle_record,
        config        => $self->{config},
    );

    $battle = Test::MockObject::Extends->new($battle);
    $battle->set_always( 'check_for_flee', undef );
    $battle->set_true('process_effects');
    $battle->set_false('stalemate_check');

    # WHEN
    my $result = $battle->execute_round;

    # THEN
    my @combat_messages = @{ $result->{messages} };
    is( scalar @combat_messages,           1,          "One combat message" );
    is( $combat_messages[0]->attacker->id, $char3->id, "Correct attacker" );
    is( $combat_messages[0]->defender->id, $char2->id, "Correct defender" );

}

sub test_end_of_combat_cleanup_creates_news : Tests(1) {
    my $self = shift;

    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );

    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, land_id => $land[0]->id );
    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, land_id => $party1->land_id );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $land[1]->id );

    my $battle_record = Test::RPG::Builder::Party_Battle->build_battle(
        $self->{schema},
        party_1 => $party1,
        party_2 => $party2,
    );

    my $battle = RPG::Combat::PartyWildernessBattle->new(
        schema        => $self->{schema},
        party_1       => $party1,
        party_2       => $party2,
        log           => $self->{mock_logger},
        battle_record => $battle_record,
        config        => $self->{config},
    );

    # WHEN
    $battle->end_of_combat_cleanup();

    # THEN
    my @history = $town->history;
    is( scalar @history, 1, "History created in town" );
}

sub test_characters_killed_by_spell_during_round_are_skipped : Tests(1) {
    my $self = shift;

    # GIVEN
    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 1, character_level => 5 );
    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 1, );

    my ($character1) = $party1->characters;
    $character1->hit_points(1);
    $character1->update;

    my ($character2) = $party2->characters;

    my $spell = $self->{schema}->resultset('Spell')->find(
        {
            spell_name => 'Flame',
        }
    );

    $self->{schema}->resultset('Memorised_Spells')->create(
        {
            spell_id        => $spell->id,
            character_id    => $character2->id,
            memorised_today => 1,
            memorise_count  => 2,
        }
    );

    $character2->last_combat_action('Cast');
    $character2->last_combat_param1( $spell->id );
    $character2->last_combat_param2( $character1->id );
    $character2->update;

    my $battle_record = Test::RPG::Builder::Party_Battle->build_battle(
        $self->{schema},
        party_1 => $party1,
        party_2 => $party2,
    );

    my $battle = RPG::Combat::PartyWildernessBattle->new(
        schema        => $self->{schema},
        party_1       => $party1,
        party_2       => $party2,
        log           => $self->{mock_logger},
        battle_record => $battle_record,
        config        => $self->{config},
    );
    $battle = Test::MockObject::Extends->new($battle);
    $battle->set_always( 'check_for_flee', undef );
    $battle->set_true('process_effects');
    $battle->mock( 'get_combatant_list', sub { ( $character2, $character1 ) } );
    $battle->set_false('check_for_end_of_combat');

    # WHEN
    my $result = $battle->execute_round();

    # THEN
    is( scalar @{ $result->{messages} }, 1, "Only 1 combat message" );
}

sub test_cant_cast_spell_on_dead_character : Tests(1) {
    my $self = shift;

    # GIVEN
    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 1 );
    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, character_level => 5 );

    my ($character1) = $party1->characters;
    $character1->character_name('loser');
    $character1->hit_points(1);
    $character1->update;

    my @party2_chars = $party2->characters;

    my $spell = $self->{schema}->resultset('Spell')->find(
        {
            spell_name => 'Flame',
        }
    );

    foreach my $char (@party2_chars) {
        $self->{schema}->resultset('Memorised_Spells')->create(
            {
                spell_id        => $spell->id,
                character_id    => $char->id,
                memorised_today => 1,
                memorise_count  => 2,
            }
        );

        $char->last_combat_action('Cast');
        $char->last_combat_param1( $spell->id );
        $char->last_combat_param2( $character1->id );
        $char->update;
    }

    my $battle_record = Test::RPG::Builder::Party_Battle->build_battle(
        $self->{schema},
        party_1 => $party1,
        party_2 => $party2,
    );

    my $battle = RPG::Combat::PartyWildernessBattle->new(
        schema        => $self->{schema},
        party_1       => $party1,
        party_2       => $party2,
        log           => $self->{mock_logger},
        battle_record => $battle_record,
        config        => $self->{config},
    );
    $battle = Test::MockObject::Extends->new($battle);
    $battle->set_always( 'check_for_flee', undef );
    $battle->set_true('process_effects');
    $battle->mock( 'get_combatant_list', sub { ( @party2_chars, $character1 ) } );
    $battle->set_false('check_for_end_of_combat');

    # WHEN
    my $result = $battle->execute_round();

    # THEN
    is( scalar @{ $result->{messages} }, 1, "Only 1 combat message" );
}
1;

