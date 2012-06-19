use strict;
use warnings;

package Test::RPG::Schema::Role::Item_Types::Scroll;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Item_Type;
use Test::RPG::Builder::Item;

sub test_use : Tests(5) {
    my $self = shift;
    
    # GIVEN    
    my $character = Test::RPG::Builder::Character->build_character($self->{schema}, hit_points => 9);
    
    my $item_type = Test::RPG::Builder::Item_Type->build_item_type(
        $self->{schema},
        item_type => 'Scroll',
        variables => [
            {
                name => 'Spell',
                create_on_insert => 1,
                special => 1,
            },
        ],
    );
    
    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        item_type_id => $item_type->id,
        variables => [
            {
                item_variable_name => 'Quantity',
                item_variable_value  => 1,
            },
            {
                item_variable_name => 'Spell',
                item_variable_value  => 'Heal',
            },

        ],
        character_id => $character->id,
    );
    
    # WHEN
    my $result = $item->use($character);
    
    # THEN
    $character->discard_changes;
    is($character->hit_points, 10, "Hit points back to max");
    
    is($item->in_storage, 0, "Item deleted");
    
    is($result->type, 'damage', "Correct type returned");
    is($result->defender->id, $character->id, "Correct 'target' returned");
    is($result->effect, 'healing', "Correct 'effect' returend");
}

1;