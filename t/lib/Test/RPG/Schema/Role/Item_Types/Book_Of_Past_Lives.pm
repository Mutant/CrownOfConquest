use strict;
use warnings;

package Test::RPG::Schema::Role::Item_Types::Book_Of_Past_Lives;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Item;

sub test_use : Tests(5) {
    my $self = shift;
    
    # GIVEN    
    my $character = Test::RPG::Builder::Character->build_character($self->{schema}, level => 10);
    
    my $skill = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Fletching',
        }
    ); 
    
    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id => $skill->id,
            character_id => $character->id,
            level => 1,
        }
    );
    
    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        item_type_name => 'Book Of Past Lives',
        variables => [
            {
                item_variable_name => 'Quantity',
                item_variable_value  => 1,
            }
        ],
        character_id => $character->id,
    );
    
    # WHEN
    my $result = $item->use;
    
    # THEN
    $character->discard_changes;
    is($character->character_skills->count, 0, "Character now has no skills");
    is($character->skill_points, 9, "Character now has skill points to use");
    
    is($item->in_storage, 0, "Item deleted");
    
    is($result->type, 'book_of_past_lives', "Correct type returned");
    is($result->defender->id, $character->id, "Correct 'defender' returned");
}

1;