use strict;
use warnings;

package Test::RPG::Schema::Skill::War_Cry;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Character;

sub startup : Tests(startup) {
    my $self = shift;

    $self->{skill} = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'War Cry',
        }
    );
}

sub setup : Tests(setup) {
    my $self = shift;

    $self->mock_dice;
}

sub test_execute : Tests(9) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    $character->last_combat_action('Attack');
    $character->update;

    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id     => $self->{skill}->id,
            character_id => $character->id,
            level        => 1,
        }
    );

    $self->{roll_result} = 4;

    # WHEN
    my %results = $char_skill->execute('combat');

    # THEN
    is( $results{fired},          1, "Marked as firing" );
    is( $results{factor_changed}, 1, "Marked as factor changing" );
    isa_ok( $results{message}, 'RPG::Combat::SkillActionResult', "Action returned" );
    is( $results{message}->skill,    'war_cry', "Correct skill name" );
    is( $results{message}->duration, 1,         "Correct duration" );

    my @effects = $character->character_effects;
    is( scalar @effects, 1, "1 effect created" );

    my $effect = $effects[0]->effect;
    is( $effect->effect_name, 'War Cry', "Effect has correct name" );
    is( $effect->modifier,    '6.00',    "Effect has correct modifier" );
    is( $effect->modified_stat, 'attack_factor', "Effect has correct modified_stat" );

}

sub test_execute_already_berserk : Tests(3) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    $character->last_combat_action('Attack');
    $character->update;

    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id     => $self->{skill}->id,
            character_id => $character->id,
            level        => 1,
        }
    );

    $self->{schema}->resultset('Effect')->create_effect( {
            effect_name    => 'War Cry',
            target         => $character,
            modifier       => 5,
            combat         => 1,
            modified_state => 'attack_factor',
            duration       => 5,
    } );

    $self->{rolls} = [ 4, 2 ];

    # WHEN
    my %results = $char_skill->execute('combat');

    # THEN
    is( $results{fired}, 0, "Not marked as firing" );

    my @effects = $character->character_effects;
    is( scalar @effects, 1, "Has 1 effect" );

    my $effect = $effects[0]->effect;
    is( $effect->time_left, '5', "Duration not changed" );

}

1;
