use strict;
use warnings;

package Test::RPG::Schema::Spell;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Creature;
use Test::RPG::Builder::Character;

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
            target      => 'Creature',
        },
        {
            spell_name => 'Energy Beam',
            effect     => 'zapping',
            target      => 'Creature',
        },
        {
            spell_name => 'Heal',
            effect     => 'healing',
            target      => 'Character',
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

sub test_cast_effect_spells : Tests(117) {
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
    );

    # GIVEN
    foreach my $test (@tests) {
        my $spell = $self->{schema}->resultset('Spell')->find( { spell_name => $test->{spell_name}, } );

        isa_ok( $spell, 'RPG::Schema::Spell::' . $test->{spell_name} );
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

1;
