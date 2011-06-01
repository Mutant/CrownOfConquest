use strict;
use warnings;

package Test::RPG::Schema::Role::Item_Types::Potion_of_Strength;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Item;

sub test_use : Tests(6) {
    my $self = shift;
    
    # GIVEN    
    my $character = Test::RPG::Builder::Character->build_character($self->{schema}, strength => 10);
    
    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        item_type_name => 'Potion of Strength',
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
    is($character->strength, 11, "Strength increased");
    is($character->attack_factor, 11, "Character af increased");
    
    is($item->in_storage, 0, "Item deleted");
    
    is($result->type, 'potion', "Correct type returned");
    is($result->defender->id, $character->id, "Correct 'defender' returned");
    is($result->damage, 1, "Correct 'damage' returend");
}

1;