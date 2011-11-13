use strict;
use warnings;

package Test::RPG::Schema::Skill::Beserker_Rage;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Character;

sub startup : Tests(startup) {
    my $self = shift;
    
    $self->mock_dice;
    
    $self->{skill} = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Beserker Rage',
        }
    );    
}

sub shutdown : Tests(shutdown) {
    my $self = shift;
    
    $self->unmock_dice;
}

sub test_execute : Tests(9) {
    my $self = shift;
    
    # GIVEN
    my $character =  Test::RPG::Builder::Character->build_character($self->{schema});
    
    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id => $self->{skill}->id,
            character_id => $character->id,
            level => 1,
        }
    );
    
    $self->{rolls} = [4, 2];
    
    # WHEN
    my %results = $char_skill->execute('combat');
    
    # THEN
    is($results{fired}, 1, "Marked as firing");
    is($results{factor_changed}, 1, "Marked as factor changing");
    isa_ok($results{message}, 'RPG::Combat::SkillActionResult', "Action returned");
    is($results{message}->skill, 'berserker_rage', "Correct skill name");
    is($results{message}->duration, 3, "Correct duration");
    
    my @effects = $character->character_effects;
    is(scalar @effects, 1, "1 effect created");
    
    my $effect = $effects[0]->effect;
    is($effect->effect_name, 'Berserk', "Effect has correct name");
    is($effect->modifier, '6.00', "Effect has correct modifier");
    is($effect->modified_stat, 'damage', "Effect has correct modified_stat");
    
}

sub test_execute_already_berserk : Tests(3) {
    my $self = shift;
    
    # GIVEN
    my $character =  Test::RPG::Builder::Character->build_character($self->{schema});
    
    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id => $self->{skill}->id,
            character_id => $character->id,
            level => 1,
        }
    );
    
    $self->{schema}->resultset('Effect')->create_effect({
            effect_name => 'Berserk',
            target => $character,
            modifier => 5,
            combat => 1,
            modified_state => 'damage',
            duration => 5,
    });    
    
    $self->{rolls} = [4, 2];
    
    # WHEN
    my %results = $char_skill->execute('combat');
    
    # THEN
    is($results{fired}, 0, "Not marked as firing");
    
    my @effects = $character->character_effects;
    is(scalar @effects, 1, "Has 1 effect");
    
    my $effect = $effects[0]->effect;
    is($effect->time_left, '5', "Duration not changed");
    
}

1;
