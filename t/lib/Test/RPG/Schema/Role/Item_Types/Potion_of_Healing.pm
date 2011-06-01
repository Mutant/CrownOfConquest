use strict;
use warnings;

package Test::RPG::Schema::Role::Item_Types::Potion_of_Healing;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Item;

sub test_use_basic : Tests(5) {
    my $self = shift;
    
    # GIVEN
    $self->mock_dice;
    $self->{roll_result} = 4;
    
    my $character = Test::RPG::Builder::Character->build_character($self->{schema}, hit_points => 5, max_hit_points => 10);
    
    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        item_type_name => 'Potion of Healing',
        variables => [
            {
                item_variable_name => 'Quantity',
                item_variable_value  => 3,
            }
        ],
        character_id => $character->id,
    );
    
    # WHEN
    my $result = $item->use;
    
    # THEN
    $character->discard_changes;
    is($character->hit_points, 9, "Character healed");
    
    is($item->variable_row('Quantity')->item_variable_value, 2, "Quantity decremented");
    
    is($result->type, 'potion', "Correct type returned");
    is($result->defender->id, $character->id, "Correct 'defender' returned");
    is($result->damage, 4, "Correct 'damage' returned");    
    
    $self->unmock_dice;
}

1;