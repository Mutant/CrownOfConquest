use strict;
use warnings;

package Test::RPG::Schema::Role::Item_Types::Potion_of_Diffusion;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Item;
use Test::RPG::Builder::Effect;

sub test_use : Tests(5) {
    my $self = shift;
    
    # GIVEN    
    my $character = Test::RPG::Builder::Character->build_character($self->{schema}, strength => 10);
    
    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        item_type_name => 'Potion of Diffusion',
        variables => [
            {
                item_variable_name => 'Quantity',
                item_variable_value  => 1,
            }
        ],
        character_id => $character->id,
    );
    
    my $effect1 = Test::RPG::Builder::Effect->build_effect(
        $self->{schema},
        effect_name => 'effect1',
        modifier => 1,
        character_id => $character->id,
    );

    my $effect2 = Test::RPG::Builder::Effect->build_effect(
        $self->{schema},
        effect_name => 'effect2',
        modifier => -1,
        character_id => $character->id,
    );
    
    # WHEN
    my $result = $item->use;
    
    # THEN
    my @effects = $character->character_effects;
    is(scalar @effects, 1, "Only 1 effect left on character");
    is($effects[0]->effect->effect_name, 'effect1', "Correct effect is left");
    
    is($item->in_storage, 0, "Item deleted");
    
    is($result->type, 'potion', "Correct type returned");
    is($result->defender->id, $character->id, "Correct 'defender' returned");
}

1;