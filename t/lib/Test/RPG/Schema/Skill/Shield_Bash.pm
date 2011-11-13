use strict;
use warnings;

package Test::RPG::Schema::Skill::Shield_Bash;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Item;

sub startup : Tests(startup) {
    my $self = shift;
    
    $self->mock_dice;
    
    $self->{skill} = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Shield Bash',
        }
    );    
}

sub shutdown : Tests(shutdown) {
    my $self = shift;
    
    $self->unmock_dice;
}

sub test_execute : Tests(5) {
    my $self = shift;
    
    # GIVEN
    my $character =  Test::RPG::Builder::Character->build_character($self->{schema});
    $character->last_combat_action('Attack');
    $character->update;
    
    my $item = Test::RPG::Builder::Item->build_item($self->{schema}, category_name => 'Shield', character_id => $character->id);    
    
    my $defender =  Test::RPG::Builder::Character->build_character($self->{schema}, hit_points => 10);
    
    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id => $self->{skill}->id,
            character_id => $character->id,
            level => 1,
        }
    );
    
    $self->{rolls} = [4, 2];
    
    # WHEN
    my %results = $char_skill->execute('combat', $character, $defender);
    
    # THEN
    is($results{fired}, 1, "Marked as firing");
    isa_ok($results{message}, 'RPG::Combat::ActionResult', "Action returned");
    is($results{message}->special_weapon, "Shield Bash", "Correct special weapon");
    is($results{message}->damage, 3, "Correct damage");
    
    $defender->discard_changes;
    is($defender->hit_points, 7, "Defenders hit points reduced");
    
}

sub test_execute_no_shield : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $character =  Test::RPG::Builder::Character->build_character($self->{schema});
    $character->last_combat_action('Attack');
    $character->update;    
    my $defender =  Test::RPG::Builder::Character->build_character($self->{schema}, hit_points => 10);
    
    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id => $self->{skill}->id,
            character_id => $character->id,
            level => 1,
        }
    );  
    
    $self->{rolls} = [4, 2];
    
    # WHEN
    my %results = $char_skill->execute('combat', $character, $defender);
    
    # THEN
    is($results{fired}, 0, "Not marked as firing");
    
    $defender->discard_changes;
    is($defender->hit_points, 10, "Defender hit points not reduced");
    
}

1;
