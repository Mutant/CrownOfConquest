package Test::RPG::Schema::CreatureGroup;

use strict;
use warnings;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::CreatureGroup;
use Test::RPG::Builder::Party;

sub startup : Test(startup => 1) {
    my $self = shift;

    $self->{mock_rpg_schema} = Test::MockObject::Extra->new();
    $self->{mock_rpg_schema}->fake_module( 'RPG::Schema', 'config' => sub { $self->{config} }, );

    use_ok 'RPG::Schema::CreatureGroup';
}

sub setup : Test(setup) {
    my $self = shift;

    $self->mock_dice();
}

sub shutdown : Test(shutdown) {
    my $self = shift;

    $self->{mock_rpg_schema}->unfake_module();
}

sub test_initiate_combat : Test(6) {
    my $self = shift;

    my $creature_group = Test::MockObject->new();
    $creature_group->set_always( 'location', $creature_group );
    $creature_group->set_always( 'land_id',  1 );
    $creature_group->mock( 'party_within_level_range', sub { RPG::Schema::CreatureGroup::party_within_level_range(@_) } );

    my $party = Test::MockObject->new();
    $party->set_true('level');

    # Orb at cg's location, and party is high enough level, so combat initiated
    $creature_group->set_always( 'orb',         $creature_group );
    $creature_group->set_always( 'can_destroy', 1 );

    is( RPG::Schema::CreatureGroup::initiate_combat( $creature_group, $party ), 1, "Combat initiated for high enough level party with Orb" );

    # Party not high enough level for orb, and too low for cg
    $creature_group->set_always( 'can_destroy', 0 );
    $self->{config}{cg_attack_max_factor_difference} = 2;
    $self->{config}{cg_attack_max_level_below_party} = 2;
    $party->set_always( 'level', 1 );
    $creature_group->set_always( 'level',            4 );
    $creature_group->set_always( 'compare_to_party', 1 );

    is( RPG::Schema::CreatureGroup::initiate_combat( $creature_group, $party ), 0, "Combat not initiated since party too low level" );

    # Party not high enough level for orb, and too high for cg
    $creature_group->set_always( 'can_destroy', 0 );
    $self->{config}{cg_attack_max_factor_difference} = 2;
    $party->set_always( 'level', 5 );
    $creature_group->set_always( 'level', 2 );

    is( RPG::Schema::CreatureGroup::initiate_combat( $creature_group, $party ), 0, "Combat not initiated since party too high level" );

    # No orb, and too high for cg
    $creature_group->set_always( 'orb', undef );
    $self->{config}{cg_attack_max_factor_difference} = 4;
    $party->set_always( 'level', 7 );
    $creature_group->set_always( 'level', 2 );

    is( RPG::Schema::CreatureGroup::initiate_combat( $creature_group, $party ), 0, "Combat not initiated since party too high level" );

    $self->{config}{cg_attack_max_factor_difference} = 1;
    $self->{config}{cg_attack_max_level_below_party} = 2;
    $self->{config}{creature_attack_chance}          = 40;
    $party->set_always( 'level', 7 );
    $creature_group->set_always( 'level', 7 );

    # Party right level, but roll higher than chance
    $self->{roll_result} = 60;

    is( RPG::Schema::CreatureGroup::initiate_combat( $creature_group, $party ), 0, "Combat not initiated roll too high" );

    # Party right level, but roll higher than chance
    $self->{roll_result} = 30;

    is( RPG::Schema::CreatureGroup::initiate_combat( $creature_group, $party ), 1, "Combat initiated, roll less than chance" );
}

sub test_party_within_level_range : Tests(5) {
    my $self = shift;

    # GIVEN
    $self->{config}->{cg_attack_max_factor_difference} = 2;
    $self->{config}->{cg_attack_max_level_below_party} = 4;

    my @tests = (
        {
            party_level          => 1,
            creature_group_level => 1,
            factor_comparison    => 3,
            expected_result      => 1,
        },
        {
            party_level          => 1,
            creature_group_level => 4,
            factor_comparison    => 1,
            expected_result      => 0,
        },
        {
            party_level          => 1,
            creature_group_level => 3,
            factor_comparison    => 3,
            expected_result      => 1,
        },
        {
            party_level          => 6,
            creature_group_level => 1,
            factor_comparison    => 1,
            expected_result      => 0,
        },
        {
            party_level          => 5,
            creature_group_level => 1,
            factor_comparison    => 1,
            expected_result      => 1,
        },
    );

    # WHEN
    my @results;
    foreach my $test (@tests) {
        my $mock_cg = Test::MockObject->new();
        $mock_cg->set_always( 'level', $test->{creature_group_level} );
        $mock_cg->set_always( 'compare_to_party', $test->{factor_comparison} );

        my $mock_party = Test::MockObject->new();
        $mock_party->set_always( 'level', $test->{party_level} );

        push @results, RPG::Schema::CreatureGroup::party_within_level_range( $mock_cg, $mock_party );
    }

    my $count = 0;
    foreach my $test (@tests) {
        is( $results[$count], $test->{expected_result}, "Result ok for test $count" );
        $count++;
    }
}

sub test_auto_heal_basic : Tests(4) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, gold => 1000 );
    $town->character_heal_budget(1000);
    $town->update;

    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema} );
    $mayor->mayor_of( $town->id );
    $mayor->update;

    my $char1 = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 5 );
    my $char2 = Test::RPG::Builder::Character->build_character( $self->{schema} );

    my $cg = $self->{schema}->resultset('CreatureGroup')->create(
        {}
    );

    for my $char ( $mayor, $char1, $char2 ) {
        $char->creature_group_id( $cg->id );
        $char->update;
    }

    # WHEN
    $cg->auto_heal;

    # THEN
    $char1->discard_changes;
    is( $char1->hit_points, 10, "Character was healed" );

    $town->discard_changes;
    is( $town->gold, 980, "Town's gold decreased" );

    my $hist_rec = $self->{schema}->resultset('Town_History')->find(
        {
            town_id => $town->id,
            type    => 'expense',
            message => 'Town Garrison Healing',
        }
    );
    is( $hist_rec->value, 20, "Cost of healing recorded" );

    my $town_message = $town->find_related(
        'history',
        {
            type => 'mayor_news',
        }
    );
    is( $town_message->message, "The town garrison was healed for the cost of 20 gold after combat", "Correct message added to mayor history" );
}

sub test_auto_heal_not_enough_in_budget : Tests(4) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, gold => 1000 );
    $town->character_heal_budget(32);
    $town->update;

    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, max_hit_points => 10, hit_points => 5 );
    $mayor->mayor_of( $town->id );
    $mayor->update;

    my $char1 = Test::RPG::Builder::Character->build_character( $self->{schema}, max_hit_points => 10, hit_points => 5 );
    my $char2 = Test::RPG::Builder::Character->build_character( $self->{schema} );

    my $cg = $self->{schema}->resultset('CreatureGroup')->create(
        {}
    );

    for my $char ( $mayor, $char1, $char2 ) {
        $char->creature_group_id( $cg->id );
        $char->update;
    }

    # WHEN
    $cg->auto_heal;

    # THEN
    $mayor->discard_changes;
    is( $mayor->hit_points, 10, "Mayor was healed" );

    $char1->discard_changes;
    is( $char1->hit_points, 8, "Character was partially healed" );

    $town->discard_changes;
    is( $town->gold, 968, "Town's gold decreased" );

    my $hist_rec = $self->{schema}->resultset('Town_History')->find(
        {
            town_id => $town->id,
            type    => 'expense',
            message => 'Town Garrison Healing',
        }
    );
    is( $hist_rec->value, 32, "Cost of healing recorded" );

}

sub test_auto_heal_not_enough_gold_in_coffers : Tests(4) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, gold => 32 );
    $town->character_heal_budget(100);
    $town->update;

    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, max_hit_points => 10, hit_points => 5 );
    $mayor->mayor_of( $town->id );
    $mayor->update;

    my $char1 = Test::RPG::Builder::Character->build_character( $self->{schema}, max_hit_points => 10, hit_points => 5 );
    my $char2 = Test::RPG::Builder::Character->build_character( $self->{schema} );

    my $cg = $self->{schema}->resultset('CreatureGroup')->create(
        {}
    );

    for my $char ( $mayor, $char1, $char2 ) {
        $char->creature_group_id( $cg->id );
        $char->update;
    }

    # WHEN
    $cg->auto_heal;

    # THEN
    $mayor->discard_changes;
    is( $mayor->hit_points, 10, "Mayor was healed" );

    $char1->discard_changes;
    is( $char1->hit_points, 8, "Character was partially healed" );

    $town->discard_changes;
    is( $town->gold, 0, "Town's gold decreased" );

    my $hist_rec = $self->{schema}->resultset('Town_History')->find(
        {
            town_id => $town->id,
            type    => 'expense',
            message => 'Town Garrison Healing',
        }
    );
    is( $hist_rec->value, 32, "Cost of healing recorded" );
}

sub test_auto_heal_some_budget_already_used : Tests(4) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, gold => 1000 );
    $town->character_heal_budget(50);
    $town->update;

    $self->{schema}->resultset('Town_History')->create(
        {
            town_id => $town->id,
            day_id  => $self->{stash}{today}->day_id,
            type    => 'expense',
            message => 'Town Garrison Healing',
            value   => 18,
        }
    );

    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, max_hit_points => 10, hit_points => 5 );
    $mayor->mayor_of( $town->id );
    $mayor->update;

    my $char1 = Test::RPG::Builder::Character->build_character( $self->{schema}, max_hit_points => 10, hit_points => 5 );
    my $char2 = Test::RPG::Builder::Character->build_character( $self->{schema} );

    my $cg = $self->{schema}->resultset('CreatureGroup')->create(
        {}
    );

    for my $char ( $mayor, $char1, $char2 ) {
        $char->creature_group_id( $cg->id );
        $char->update;
    }

    # WHEN
    $cg->auto_heal;

    # THEN
    $mayor->discard_changes;
    is( $mayor->hit_points, 10, "Mayor was healed" );

    $char1->discard_changes;
    is( $char1->hit_points, 8, "Character was partially healed" );

    $town->discard_changes;
    is( $town->gold, 968, "Town's gold decreased" );

    my $hist_rec = $self->{schema}->resultset('Town_History')->find(
        {
            town_id => $town->id,
            type    => 'expense',
            message => 'Town Garrison Healing',
        }
    );
    is( $hist_rec->value, 50, "Cost of healing recorded" );
}

sub test_auto_heal_no_healing_if_no_mayor : Tests(2) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, gold => 1000 );
    $town->character_heal_budget(50);
    $town->update;

    my $char1 = Test::RPG::Builder::Character->build_character( $self->{schema}, max_hit_points => 10, hit_points => 5 );
    my $char2 = Test::RPG::Builder::Character->build_character( $self->{schema} );

    my $cg = $self->{schema}->resultset('CreatureGroup')->create(
        {}
    );

    for my $char ( $char1, $char2 ) {
        $char->creature_group_id( $cg->id );
        $char->update;
    }

    # WHEN
    $cg->auto_heal;

    # THEN
    $char1->discard_changes;
    is( $char1->hit_points, 5, "Character was not healed" );

    $town->discard_changes;
    is( $town->gold, 1000, "Town's gold the same" );
}

sub test_flee_chance : Tests(1) {
    my $self = shift;

    # GIVEN
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, creature_level => 3 );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 1, level => 7 );

    $self->{config}{chance_creatures_flee_per_level_diff} = 2;

    # WHEN
    my $flee_chance = $cg->flee_chance($party);

    # THEN
    is( $flee_chance, 4, "Flee chance is correct" );
}

sub test_flee_chance_with_tactics : Tests(1) {
    my $self = shift;

    # GIVEN
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, creature_level => 3 );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 1, level => 10 );
    my ($char) = $party->characters;

    my $skill = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Tactics',
        }
    );

    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id     => $skill->id,
            character_id => $char->id,
            level        => 5,
        }
    );

    $self->{config}{chance_creatures_flee_per_level_diff} = 2;

    # WHEN
    my $flee_chance = $cg->flee_chance($party);

    # THEN
    is( $flee_chance, 4, "Flee chance is correct with Tactics skill" );
}

sub test_flee_chance_with_strategy : Tests(1) {
    my $self = shift;

    # GIVEN
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, creature_level => 3 );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 1, level => 10 );
    my $char = Test::RPG::Builder::Character->build_character( $self->{schema}, creature_group_id => $cg->id, level => 3 );

    my $skill = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Strategy',
        }
    );

    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id     => $skill->id,
            character_id => $char->id,
            level        => 5,
        }
    );

    $self->{config}{chance_creatures_flee_per_level_diff} = 2;

    # WHEN
    my $flee_chance = $cg->flee_chance($party);

    # THEN
    is( $flee_chance, 16, "Flee chance is correct with Strategy skill" );
}

sub test_characters_in_cg_awarded_xp {
    my $self = shift;

    # GIVEN
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, creature_level => 3 );
    my $char = Test::RPG::Builder::Character->build_character( $self->{schema}, creature_group_id => $cg->id, level => 3 );
}

1;

