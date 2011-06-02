use strict;
use warnings;

package Test::RPG::Schema::Role::Item_Types::Potion_of_Clarity;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Item;
use Test::RPG::Builder::Effect;

sub test_use : Tests(4) {
    my $self = shift;
    
    # GIVEN    
    my $character = Test::RPG::Builder::Character->build_character($self->{schema}, class => 'Mage');
    
    my $spell = $self->{schema}->resultset('Spell')->find(
        {
            spell_name => 'Flame',
        }
    );
    
	my $memorised_spell = $self->{schema}->resultset('Memorised_Spells')->create(
		{
			character_id => $character->id,
			spell_id     => $spell->id,
			memorised_today => 1,
			memorise_count => 1,
			number_cast_today => 1,
			memorise_count_tomorrow => 1,
			memorise_tomorrow => 1,
		},
	);    
    
    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        item_type_name => 'Potion of Clarity',
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
    $memorised_spell->discard_changes;
    is($memorised_spell->number_cast_today, 0, "Cast count reset");
    
    is($item->in_storage, 0, "Item deleted");
    
    is($result->type, 'potion', "Correct type returned");
    is($result->defender->id, $character->id, "Correct 'defender' returned");
}

1;