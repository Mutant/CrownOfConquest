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

sub test_creature_action_wiped_out_party : Tests(11) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 1 );
    my ($character) = $party->characters;
    $character->hit_points(1);
    $character->update;

    my $cg       = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
    my $creature = ( $cg->creatures )[0];

    my $battle = RPG::Combat::CreatureWildernessBattle->new(
        schema         => $self->{schema},
        party          => $party,
        creature_group => $cg,
        config         => { front_rank_attack_chance => 1 },
    );

    $battle = Test::MockObject::Extends->new($battle);
    $battle->mock( 'attack', sub { $_[2]->hit_points(0); $_[2]->update; return 1 } );

    $self->{roll_result} = 4;

    # WHEN
    my $results = $battle->creature_action($creature);

    # THEN
    isa_ok( $results->[0], "RPG::Schema::Character", "opponent was a character" );
    is( $results->[0]->party_id, $party->id, ".. from the correct party" );
    is( $results->[1],           1,          "Damage returned correctly" );

    my ( $method, $args ) = $battle->next_call();

    is( $method, "attack", "Attack called" );
    isa_ok( $args->[1], "RPG::Schema::Creature", "First param passed to attack was a creature" );
    is( $args->[1]->id, $creature->id, "Correct creature passed" );
    isa_ok( $args->[2], "RPG::Schema::Character", "Second param passed to attack was a character" );
    is( $args->[2]->id, $results->[0]->id, "Correct character passed" );

    undef $battle;    # Force write to db

    $party->discard_changes;
    is( defined $party->defunct, 1, "party now defunct" );

    my $combat_log = $self->{schema}->resultset('Combat_Log')->find(
        {
            opponent_1_id => $party->id,
            opponent_2_id => $cg->id,
        },
    );
    is( $combat_log->outcome, 'creatures_won', "Outcome recorded in log" );
    is( defined $combat_log->encounter_ended, 1, "Combat marked as ended in log" );

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
    );

    # WHEN
    my $result = $battle->check_for_flee();

    # THEN
    is( $result, 0, "No fleeing, since creatures not allowed to flee" );

}

sub test_check_for_flee_successful_flee : Tests(7) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
    $party->in_combat_with($cg->id);
    $party->update;
    
    $party = Test::MockObject::Extends->new($party);
    $party->set_always('level', 10);

    my $battle = RPG::Combat::CreatureWildernessBattle->new(
        schema             => $self->{schema},
        party              => $party,
        creature_group     => $cg,
        creatures_can_flee => 1,
        config => {chance_creatures_flee_per_level_diff => 1},
    );
    
    my $combat_log = Test::MockObject->new();
    $combat_log->set_always('rounds', 3);
    $combat_log->set_true('outcome');
    $combat_log->set_true('encounter_ended');
    $combat_log->set_true('update');
    
    my $land = Test::MockObject->new();
    $land->set_always('id',1);
    
    $battle = Test::MockObject::Extends->new($battle);
    $battle->set_always('combat_log', $combat_log);
    $battle->set_always('get_sector_to_flee_to', $land);
    $battle->set_true('session');
    
    $self->mock_dice;
    undef $self->{rolls};
    $self->{roll_result} = 1;

    # WHEN
    my $result = $battle->check_for_flee();

    # THEN
    is( $result, 1, "Creatures fled" );
    
    $cg->discard_changes;
    is($cg->land_id, 1, "Fled to correct land");
    
    $party->discard_changes;
    is($party->in_combat_with, undef, "party no longer in combat");
    
    my ($name, $args) = $combat_log->next_call(3);
    is($name, "outcome", "outcome of combat log set");
    is($args->[1], 'creatures_fled', "outcome set correctly");
    
    ($name, $args) = $combat_log->next_call();
    is($name, "encounter_ended", "encounter ended of combat log set");
    isa_ok($args->[1], 'DateTime', "encounted ended set correctly");    

}

1;
