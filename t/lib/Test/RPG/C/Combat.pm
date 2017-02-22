use strict;
use warnings;

package Test::RPG::C::Combat;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::MockModule;
use Test::More;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Item;
use Test::RPG::Builder::CreatureGroup;
use Test::RPG::Builder::Effect;

use Data::Dumper;
use DateTime;

sub combat_startup : Test(startup => 1) {
    my $self = shift;

    use_ok('RPG::C::Combat');
}

sub test_fight : Tests(5) {
    my $self = shift;

    # GIVEN
    my $result = { display_messages => { 1 => ['messages from combat'] }, };

    my $mock_battle = Test::MockObject::Extra->new();
    my %new_args;
    $mock_battle->fake_module(
        'RPG::Combat::CreatureWildernessBattle',
        new => sub {
            shift @_;
            %new_args = @_;
            return $mock_battle;
        },
    );
    $mock_battle->mock(
        'execute_round',
        sub {
            return $result;
        },
    );

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
    $party->in_combat_with( $cg->id );
    $self->{stash}{party}          = $party;
    $self->{stash}{party_location} = $party->location;

    my $template_args;
    $self->{mock_forward}->{'RPG::V::TT'} = sub { $template_args = \@_ };
    $self->{mock_forward}->{'/panel/refresh'} = sub { };
    $self->{mock_forward}->{'/combat/process_round_result'} = sub { RPG::C::Combat->process_round_result( $self->{c}, $_[0]->[0] ) };
    $self->{mock_forward}->{'/combat/display_cg'} = sub { };

    # WHEN
    RPG::C::Combat->fight( $self->{c} );

    # THEN
    is( $new_args{creature_group}->id, $cg->id, "Creature group passed in correctly" );
    is( $new_args{party}->id, $party->id, "Creature group passed in correctly" );
    is( $new_args{creatures_can_flee}, 1, "Creatures allowed to flee" );
    $mock_battle->called_ok('execute_round');

    is( $self->{stash}{combat_messages}[0], "messages from combat", "Combat messages stored in stash" );

    $mock_battle->unfake_module('RPG::Combat::CreatureWildernessBattle');
}

sub test_flee_flee_successful : Tests(7) {
    my $self = shift;

    # GIVEN
    my $result = { party_fled => 1, };

    my $mock_battle = Test::MockObject::Extra->new();
    my %new_args;
    $mock_battle->fake_module(
        'RPG::Combat::CreatureWildernessBattle',
        new => sub {
            shift @_;
            %new_args = @_;
            return $mock_battle;
        },
    );

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
    $party->in_combat_with( $cg->id );
    $self->{stash}{party}          = $party;
    $self->{stash}{party_location} = $party->location;

    my $orig_location = $party->land_id;

    $mock_battle->mock(
        'execute_round',
        sub {
            $party->land_id( $party->land_id + 1 );
            $party->update;
            return $result;
        },
    );

    my $template_args;
    $self->{mock_forward}->{'RPG::V::TT'} = sub { $template_args = \@_ };
    $self->{mock_forward}->{'/panel/refresh'} = sub { };
    $self->{mock_forward}->{'/combat/process_flee_result'} = sub { RPG::C::Combat->process_flee_result( $self->{c}, $_[0]->[0] ) };

    # WHEN
    RPG::C::Combat->flee( $self->{c} );

    # THEN
    is( $new_args{creature_group}->id, $cg->id, "Creature group passed in correctly" );
    is( $new_args{party}->id, $party->id, "Creature group passed in correctly" );
    is( $new_args{creatures_can_flee}, 1, "Creatures allowed to flee" );
    is( $new_args{party_flee_attempt}, 1, "Flee attempted" );
    is( $self->{stash}{messages}, "You got away!", "Flee message set" );
    is( $self->{stash}{party}->land_id, $orig_location + 1, "Party record in stash refreshed" );
    is( $self->{stash}{creature_group}, undef, "Creature group in stash cleared" );

    $mock_battle->unfake_module('RPG::Combat::CreatureWildernessBattle');
}

sub test_select_action : Tests(3) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );

    $self->{params}{action_param} = [ '1', '2' ];
    $self->{params}{character_id} = $character->id;
    $self->{params}{action}       = 'Attack';

    $self->{mock_forward}{'/panel/refresh'} = sub { };

    # WHEN
    RPG::C::Combat->select_action( $self->{c} );

    # THEN
    $character->discard_changes;
    is( $character->last_combat_action, 'Attack', "Last combat action set correctly" );
    is( $character->last_combat_param1, '1', "Last action param 1 set correctly" );
    is( $character->last_combat_param2, '2', "Last action param 2 set correctly" );
}

sub process_round_result_party_wiped_out : Tests(5) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    $party->defunct( DateTime->now() );
    $party->update;

    my $result = {
        display_messages => {
            1 => ['some message'],
            2 => ['other message'],
        },
        combat_complete => 1,
    };

    my $params;
    $self->{mock_forward}{'/panel/refresh'} = sub { $params = $_[0]; };

    $self->{mock_forward}{'RPG::V::TT'} = sub { 'foo' };
    $self->{stash}{party} = $party;

    # WHEN
    RPG::C::Combat->process_round_result( $self->{c}, $result );

    # THEN
    is( $self->{stash}{messages_path}, '/combat/main', "Messages path set to main" );
    is( scalar @{ $self->{stash}{combat_messages} }, 1, "Two messages added" );
    is( $self->{stash}{combat_messages}[0], "some message", "Correct message given" );
    is( $self->{stash}{combat_complete}, 1, "Combat complete recorded in stash" );
    is_deeply( $params, [ 'messages', 'party_status', ], "Correct panels refreshed" );
}

sub test_main_already_loaded_cg_picked_up_new_effects : Tests(2) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );

    my $creature = ( $cg->creatures )[0];

    my $effect = Test::RPG::Builder::Effect->build_effect( $self->{schema}, creature_id => $creature->id );

    $self->{stash}->{creature_group} = $cg;
    $self->{stash}->{party}          = $party;

    my $template_args;
    $self->{mock_forward}->{'RPG::V::TT'} = sub { $template_args = \@_ };

    # WHEN
    RPG::C::Combat->display_opponents( $self->{c}, $cg );

    # THEN
    my %creature_effects_by_id = %{ $template_args->[0][0]{params}{effects_by_id}{creature} };
    is( scalar @{ $creature_effects_by_id{ $creature->id } }, 1, "One effect found for creature" );
    is( $creature_effects_by_id{ $creature->id }->[0]->id, $effect->id, "Correct effect found" );
}

sub test_execute_attack_confirm_attack_required : Tests(3) {
    my $self = shift;

    # GIVEN
    $self->{config}->{cg_attack_max_factor_difference} = 2;
    $self->{config}->{cg_attack_max_level_below_party} = 4;

    my @tests = (
        {
            cg_level          => 1,
            party_level       => 1,
            expected_result   => 0,
            factor_comparison => 3,
            name              => 'cg and party level the same',
        },
        {
            cg_level          => 3,
            party_level       => 1,
            factor_comparison => 2,
            expected_result   => 0,
            name              => 'cg level on the threshold',
        },
        {
            cg_level          => 4,
            party_level       => 1,
            expected_result   => 1,
            factor_comparison => 1,
            name              => 'cg level above the threshold',
        },
    );

    my $template_args;
    $self->{mock_forward}->{'RPG::V::TT'} = sub { $template_args = \@_ };
    my $confirm_required;
    $self->{mock_forward}->{'/panel/create_submit_dialog'} = sub { $confirm_required = 1 };
    $self->{mock_forward}->{'/panel/refresh'} = sub { };

    # WHEN
    my %results;
    foreach my $test (@tests) {
        $confirm_required = 0;

        my $party = Test::RPG::Builder::Party->build_party(
            $self->{schema},
            character_count => 3,
            character_level => $test->{party_level},
        );

        $self->{c}->stash->{party}          = $party;
        $self->{c}->stash->{party_location} = $party->location;

        my $creature_group = Test::RPG::Builder::CreatureGroup->build_cg(
            $self->{schema},
            creature_level => $test->{cg_level},
            land_id        => $party->land_id,
        );

        $creature_group = Test::MockObject::Extends->new($creature_group);
        $creature_group->set_always( 'compare_to_party', $test->{factor_comparison} );

        RPG::C::Combat->execute_attack( $self->{c}, $creature_group );

        $results{ $test->{name} } = $confirm_required;
    }

    # THEN
    foreach my $test (@tests) {
        is( $results{ $test->{name} }, $test->{expected_result}, $test->{name} . " - Confirm attack set correctly" );
    }

}

1;
