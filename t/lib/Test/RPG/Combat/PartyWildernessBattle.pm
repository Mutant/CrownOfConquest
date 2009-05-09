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

sub test_finish : Tests(3) {
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
        schema        => $self->{schema},
        party_1       => $party1,
        party_2       => $party2,
        log           => $self->{mock_logger},
        battle_record => $battle_record,
        config        => { xp_multiplier_character => 10 },
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

sub test_party_flee : Tests(6) {
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

    $battle_record->discard_changes;
    is( defined $battle_record->complete, 1, "Battle record marked as complete" );

    is( $battle->combat_log->outcome,                 'opp2_fled', "Combat log outcome set correctly" );
    is( defined $battle->combat_log->encounter_ended, 1,           "Combat log encounter ended set" );
}

sub test_offline_party_flee : Tests(7) {
    my $self = shift;

    # GIVEN
    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    $party1 = Test::MockObject::Extends->new($party1);
    $party1->set_false('is_online');
    $party1->set_true('is_over_flee_threshold');
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

    $self->{config}{maximum_turns} = 100;

    my $land = Test::MockObject->new();
    $land->set_always( 'id', 999 );
    $land->set_isa('RPG::Schema::Land');
    $land->set_always( 'movement_cost', 1 );

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

    $battle_record->discard_changes;
    is( defined $battle_record->complete, 1, "Battle record marked as complete" );

    is( $battle->combat_log->outcome,                 'opp1_fled', "Combat log outcome set correctly" );
    is( defined $battle->combat_log->encounter_ended, 1,           "Combat log encounter ended set" );

    ok( $battle->combat_log->xp_awarded > 0, "Xp awarded" );
}

1;
