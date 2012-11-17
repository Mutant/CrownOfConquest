use strict;
use warnings;

package Test::RPG::Schema::Spell;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Creature;
use Test::RPG::Builder::Character;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Item;
use Test::RPG::Builder::Effect;

sub startup : Tests(startup=>1) {
    use_ok('RPG::Schema::Spell');
}

sub test_result_inflated_into_class : Tests(1) {
    my $self = shift;

    # GIVEN

    # WHEN
    my $spell = $self->{schema}->resultset('Spell')->find( { spell_name => 'Energy Beam', } );

    # THEN
    isa_ok( $spell, 'RPG::Schema::Spell::Energy_Beam', "Spell blessed into right class" );
}

sub test_cast_damage_spells : Tests(27) {
    my $self = shift;

    my @tests = (
        {
            spell_name => 'Flame',
            effect     => 'frying',
            target     => 'Creature',
        },
        {
            spell_name => 'Energy Beam',
            effect     => 'zapping',
            target     => 'Creature',
        },
        {
            spell_name => 'Heal',
            effect     => 'healing',
            target     => 'Character',
        },
    );

    $self->mock_dice;
    $self->{roll_result} = 3;

    # GIVEN
    foreach my $test (@tests) {
        my $spell = $self->{schema}->resultset('Spell')->find( { spell_name => $test->{spell_name}, } );
        my $target;
        if ( $test->{target} eq 'Character' ) {
            $target = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 5, hit_points_max => 8 );
        }
        else {
            $target = Test::RPG::Builder::Creature->build_creature( $self->{schema}, hit_points_current => 5 );
        }
        my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );

        my $mem_spell = $self->{schema}->resultset('Memorised_Spells')->create(
            {
                character_id      => $character->id,
                spell_id          => $spell->id,
                memorise_count    => 1,
                number_cast_today => 0,
            }
        );

        # WHEN
        my $result = $spell->cast( $character, $target );

        # THEN
        isa_ok( $result->attacker, 'RPG::Schema::Character' );
        is( $result->attacker->id, $character->id, 'Caster set as character in result' );

        isa_ok( $result->defender, 'RPG::Schema::' . $test->{target} );
        is( $result->defender->id, $target->id, 'Target set correctly in result' );

        is( $result->damage, 3,               "Damage set in result" );
        is( $result->effect, $test->{effect}, "Effect set correctly" );
        is( $result->type,   'damage',        "Type set correctly" );

        $mem_spell->discard_changes;
        is( $mem_spell->casts_left_today, 0, "Memorised spell count decremented" );

        $target->discard_changes;
        my $expected_hp = $test->{target} eq 'Character' ? 8 : 2;
        my $actual_hp = $test->{target} eq 'Character' ? $target->hit_points : $target->hit_points_current;
        is( $actual_hp, $expected_hp, "Target has sustained damage" );
    }

}

sub test_cast_effect_spells : Tests(130) {
    my $self = shift;

    my @tests = (
        {
            spell_name  => 'Shield',
            effect_name => 'Shield',
            target      => 'Character',
            effect      => 'protecting him',
        },
        {
            spell_name  => 'Blades',
            effect_name => 'Blades',
            target      => 'Character',
            effect      => 'enhancing his weapon',
        },
        {
            spell_name  => 'Bless',
            effect_name => 'Bless',
            target      => 'Character',
            effect      => 'blessing him',
        },
        {
            spell_name  => 'Haste',
            effect_name => 'Haste',
            target      => 'Character',
            effect      => 'speeding his attack',
        },
        {
            spell_name  => 'Weaken',
            effect_name => 'Weakened',
            target      => 'Creature',
            effect      => 'weakening it',
        },
        {
            spell_name  => 'Confuse',
            effect_name => 'Confused',
            target      => 'Creature',
            effect      => 'confusing it',
        },
        {
            spell_name  => 'Curse',
            effect_name => 'Cursed',
            target      => 'Creature',
            effect      => 'cursing it',
        },
        {
            spell_name  => 'Entangle',
            effect_name => 'Entangled',
            target      => 'Creature',
            effect      => 'entangling it',
        },
        {
            spell_name  => 'Slow',
            effect_name => 'Slowed',
            target      => 'Creature',
            effect      => 'slowing it',
        },
        {
            spell_name  => 'Poison Blast',
            effect_name => 'Poisoned',
            target      => 'Creature',
            effect      => 'poisoning it',
        },        
    );

    # GIVEN
    foreach my $test (@tests) {
        my $spell = $self->{schema}->resultset('Spell')->find( { spell_name => $test->{spell_name}, } );

        my $pkg_spell_name = $test->{spell_name};
        $pkg_spell_name =~ s/ /_/g;

        isa_ok( $spell, 'RPG::Schema::Spell::' . $pkg_spell_name );
        my $caster = Test::RPG::Builder::Character->build_character( $self->{schema} );

        my $target;
        if ( $test->{target} eq 'Character' ) {
            $target = Test::RPG::Builder::Character->build_character( $self->{schema} );
        }
        else {
            $target = Test::RPG::Builder::Creature->build_creature( $self->{schema} );
        }

        my $mem_spell = $self->{schema}->resultset('Memorised_Spells')->create(
            {
                character_id      => $caster->id,
                spell_id          => $spell->id,
                memorise_count    => 1,
                number_cast_today => 0,
            }
        );

        # WHEN
        my $result = $spell->cast( $caster, $target );

        # THEN
        isa_ok( $result->attacker, 'RPG::Schema::Character' );
        is( $result->attacker->id, $caster->id, 'Caster set as character in result' );

        isa_ok( $result->defender, 'RPG::Schema::' . $test->{target} );
        is( $result->defender->id, $target->id, 'Target set as character in result' );

        is( $result->duration > 1, 1,               "Duration set in result" );
        is( $result->effect,       $test->{effect}, "Effect set correctly" );
        is( $result->type,         'effect',        "Type set correctly" );

        $mem_spell->discard_changes;
        is( $mem_spell->casts_left_today, 0, "Memorised spell count decremented" );

        my @effects = $test->{target} eq 'Character' ? $target->character_effects : $target->creature_effects;
        is( scalar @effects,                    1,                    "Target has an effect" );
        is( $effects[0]->effect->effect_name,   $test->{effect_name}, "Effect name set correctly" );
        is( $effects[0]->effect->time_left > 0, 1,                    "time left set correctly" );
        is( $effects[0]->effect->combat,        1,                    "combat set correctly" );
    }

}

sub test_cast_party_effect_spells : Tests(14) {
    my $self = shift;

    my @tests = (
        {
            spell_name  => 'Watcher',
            effect_name => 'Watcher',
            effect      => 'watching the party',
            combat      => 0,
            time_type   => 'day',
        },
    );

    # GIVEN
    foreach my $test (@tests) {
        my $spell = $self->{schema}->resultset('Spell')->find( { spell_name => $test->{spell_name}, } );

        isa_ok( $spell, 'RPG::Schema::Spell::' . $test->{spell_name} );
        my $caster = Test::RPG::Builder::Character->build_character( $self->{schema} );

        my $target = Test::RPG::Builder::Party->build_party( $self->{schema} );

        my $mem_spell = $self->{schema}->resultset('Memorised_Spells')->create(
            {
                character_id      => $caster->id,
                spell_id          => $spell->id,
                memorise_count    => 1,
                number_cast_today => 0,
            }
        );

        # WHEN
        my $result = $spell->cast( $caster, $target );

        # THEN
        isa_ok( $result->attacker, 'RPG::Schema::Character' );
        is( $result->attacker->id, $caster->id, 'Caster set as character in result' );

        isa_ok( $result->defender, 'RPG::Schema::Party' );
        is( $result->defender->id, $target->id, 'Target set as party in result' );

        is( $result->duration > 1, 1,               "Duration set in result" );
        is( $result->effect,       $test->{effect}, "Effect set correctly" );
        is( $result->type,         'party_effect',  "Type set correctly" );

        $mem_spell->discard_changes;
        is( $mem_spell->casts_left_today, 0, "Memorised spell count decremented" );

        my @effects = $target->party_effects;
        is( scalar @effects,                    1,                    "Target has an effect" );
        is( $effects[0]->effect->effect_name,   $test->{effect_name}, "Effect name set correctly" );
        is( $effects[0]->effect->time_left > 0, 1,                    "time left set correctly" );
        is( $effects[0]->effect->combat,        $test->{combat},      "combat set correctly" );
        is( $effects[0]->effect->time_type,     $test->{time_type},   "time type set correctly" );
    }

}

sub test_ice_bolt : Test(12) {
    my $self = shift;
    
    my $spell = $self->{schema}->resultset('Spell')->find( { spell_name => 'Ice Bolt', } );
    my $target = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 5, hit_points_max => 8 );
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );

    my $mem_spell = $self->{schema}->resultset('Memorised_Spells')->create(
        {
            character_id      => $character->id,
            spell_id          => $spell->id,
            memorise_count    => 1,
            number_cast_today => 0,
        }
    );
    
    $self->mock_dice;
    $self->{roll_result} = 3;    

    # WHEN
    my $result = $spell->cast( $character, $target );

    # THEN
    isa_ok( $result->attacker, 'RPG::Schema::Character' );
    is( $result->attacker->id, $character->id, 'Caster set as character in result' );

    is( $result->defender->id, $target->id, 'Target set correctly in result' );

    is( $result->damage, 3,               "Damage set in result" );
    is( $result->effect, 'freezing', "Effect set correctly" );
    is( $result->type,   'damage',        "Type set correctly" );

    $mem_spell->discard_changes;
    is( $mem_spell->casts_left_today, 0, "Memorised spell count decremented" );

    $target->discard_changes;
    is( $target->hit_points, 2, "Target has sustained damage" );   
    
    my @effects = $target->character_effects;
    is( scalar @effects,                    1,                    "Target has an effect" );
    is( $effects[0]->effect->effect_name,   'Frozen', "Effect name set correctly" );
    is( $effects[0]->effect->time_left > 0, 1,                    "time left set correctly" );
    is( $effects[0]->effect->combat,        1,                    "combat set correctly" );
    
    $self->unmock_dice;     
} 

sub test_recalled_spell : Test(2) {
    my $self = shift;
    
    # GIVEN    
    my $spell = $self->{schema}->resultset('Spell')->find( { spell_name => 'Flame', } );
    my $target = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 5, hit_points_max => 8 );    
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    
    my $skill = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Recall',
        }
    );        
    
    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id => $skill->id,
            character_id => $character->id,
            level => 100,
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
    
    # WHEN
    my $result = $spell->cast( $character, $target );
    
    # THEN
    is($result->recalled, 1, "Spell was recalled");
    
    $mem_spell->discard_changes;
    is( $mem_spell->casts_left_today, 1, "Memorised spell count not decremented" );    
}

sub test_cast_flame_resisted : Tests(2) {
    my $self = shift;
    
    # GIVEN    
    my $spell = $self->{schema}->resultset('Spell')->find( { spell_name => 'Flame', } );
    my $target = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 5, hit_points_max => 8 );
    $target->resist_fire(100);
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    
    my $mem_spell = $self->{schema}->resultset('Memorised_Spells')->create(
        {
            character_id      => $character->id,
            spell_id          => $spell->id,
            memorise_count    => 1,
            number_cast_today => 0,
        }
    );
    
    # WHEN
    my $result = $spell->cast( $character, $target );
    
    # THEN
    is($result->resisted, 1, "Spell was resisted");
    
    $target->discard_changes;
    is($target->hit_points, 5, "Target wasn't damaged");
}

sub test_cast_detonate_no_vial : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $spell = $self->{schema}->resultset('Spell')->find( { spell_name => 'Detonate', } );
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    
    my $mem_spell = $self->{schema}->resultset('Memorised_Spells')->create(
        {
            character_id      => $character->id,
            spell_id          => $spell->id,
            memorise_count    => 1,
            number_cast_today => 0,
        }
    );    
    
    # WHEN
    my $result = $spell->cast( $character, $party );
    
    # THEN
    is($result->didnt_cast, 1, "Spell wasn't cast");
    is($result->custom->{no_vial}, 1, "Not cast as caster had no vial");
}

sub test_cast_detonate_with_single_vial : Tests(5) {
    my $self = shift;
    
    # GIVEN
    my $spell = $self->{schema}->resultset('Spell')->find( { spell_name => 'Detonate', } );
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    
    my $mem_spell = $self->{schema}->resultset('Memorised_Spells')->create(
        {
            character_id      => $character->id,
            spell_id          => $spell->id,
            memorise_count    => 1,
            number_cast_today => 0,
        }
    );    
    
    my $vial = Test::RPG::Builder::Item->build_item($self->{schema}, 
        item_type_name => 'Vial of Dragons Blood', 
        character_id => $character->id,
        variables => [
            {
                item_variable_name => 'Quantity',
                item_variable_value => 1,
            },
        ],
    );
    
    # WHEN
    my $result = $spell->cast( $character, $party );
    
    # THEN
    is($result->didnt_cast, 0, "Spell was cast");
    is($result->custom->{planted}, 1, "Bomb was planted");
    
    my $bomb = $self->{schema}->resultset('Bomb')->find(
        {
            party_id => $party->id,
        }
    );
    
    is($bomb->level, $character->level, "Bomb created with caster's level");
    is($bomb->land_id, $party->land_id, "Bomb created in correct location");
    
    $vial->discard_changes;
    is($vial->in_storage, 0, "Vial was deleted");
}

sub test_cast_detonate_with_stacked_vial : Tests(5) {
    my $self = shift;
    
    # GIVEN
    my $spell = $self->{schema}->resultset('Spell')->find( { spell_name => 'Detonate', } );
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    
    my $mem_spell = $self->{schema}->resultset('Memorised_Spells')->create(
        {
            character_id      => $character->id,
            spell_id          => $spell->id,
            memorise_count    => 1,
            number_cast_today => 0,
        }
    );    
    
    my $vial = Test::RPG::Builder::Item->build_item($self->{schema}, 
        item_type_name => 'Vial of Dragons Blood', 
        character_id => $character->id,
        variables => [
            {
                item_variable_name => 'Quantity',
                item_variable_value => 3,
            },
        ],
    );
    
    # WHEN
    my $result = $spell->cast( $character, $party );
    
    # THEN
    is($result->didnt_cast, 0, "Spell was cast");
    is($result->custom->{planted}, 1, "Bomb was planted");
    
    my $bomb = $self->{schema}->resultset('Bomb')->find(
        {
            party_id => $party->id,
        }
    );
    
    is($bomb->level, $character->level, "Bomb created with caster's level");
    is($bomb->land_id, $party->land_id, "Bomb created in correct location");
    
    $vial->discard_changes;
    is($vial->variable('Quantity'), 2, "Vial was used");
}

sub test_cleanse : Tests(3) {
    my $self = shift;
    
    # GIVEN    
    my $spell = $self->{schema}->resultset('Spell')->find( { spell_name => 'Cleanse', } );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    my $caster = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id );
    my $target = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id );
    
    my $mem_spell = $self->{schema}->resultset('Memorised_Spells')->create(
        {
            character_id      => $caster->id,
            spell_id          => $spell->id,
            memorise_count    => 1,
            number_cast_today => 0,
        }
    ); 
    
    my $effect1 = Test::RPG::Builder::Effect->build_effect(
        $self->{schema},
        effect_name => 'effect1',
        modifier => 1,
        character_id => $target->id,
    );

    my $effect2 = Test::RPG::Builder::Effect->build_effect(
        $self->{schema},
        effect_name => 'effect2',
        modifier => -1,
        character_id => $target->id,
    );
    
    # WHEN
    my $result = $spell->cast( $caster, $target );    
        
    # THEN
    my @effects = $target->character_effects;
    is(scalar @effects, 1, "Only 1 effect left on target character");
    is($effects[0]->effect->effect_name, 'effect1', "Correct effect is left");
        
    is($result->type, 'cleanse', "Correct type returned");    
    
}

sub test_cleanse_select_target : Tests(1) {
    my $self = shift;
    
    # GIVEN    
    my $spell = $self->{schema}->resultset('Spell')->find( { spell_name => 'Cleanse', } );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 3 );
    my @chars = $party->characters;
    my $caster = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id );
    
    
    my $mem_spell = $self->{schema}->resultset('Memorised_Spells')->create(
        {
            character_id      => $caster->id,
            spell_id          => $spell->id,
            memorise_count    => 1,
            number_cast_today => 0,
        }
    ); 
    
    my $effect1 = Test::RPG::Builder::Effect->build_effect(
        $self->{schema},
        effect_name => 'effect1',
        modifier => 1,
        character_id => $chars[0]->id,
    );

    my $effect2 = Test::RPG::Builder::Effect->build_effect(
        $self->{schema},
        effect_name => 'effect2',
        modifier => -1,
        character_id => $chars[1]->id,
    );
    
    # WHEN
    my $target = $spell->select_target( $party->characters );    
        
    # THEN
    is($target->id, $chars[1]->id, "Correct character targetted");   
    
}

1;
