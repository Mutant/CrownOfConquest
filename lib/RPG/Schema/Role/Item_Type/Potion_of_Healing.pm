package RPG::Schema::Role::Item_Type::Potion_of_Healing;

use strict;
use warnings;

use Moose::Role;

use Games::Dice::Advanced;
use RPG::Combat::SpellActionResult;

sub use {
    my $self = shift;
    
    return unless $self->is_usable;
    
    my $character = $self->belongs_to_character;
    
    return unless $character;
    
    my $heal = Games::Dice::Advanced->roll('2d8');
    
    $character->change_hit_points($heal);
    $character->update;
    
    my $quantity = $self->variable('Quantity');
    $quantity--;
    if ($quantity == 0) {
        $self->delete;   
    }
    else {
        $self->variable_row('Quantity', $quantity);
    }
    
    return RPG::Combat::SpellActionResult->new(
        {
            type => 'potion',
            spell_name => 'healing',
            defender => $character,
            attacker => $character,
            effect => 'hit points',
            damage => $heal,
        }
    );
}

sub label {
    my $self = shift;
    
    return "Drink Potion of Healing (" . $self->variable('Quantity') . ')';   
}

sub target {
    return 'self';
}

sub is_usable {
    my $self = shift;
    
    my $character = $self->belongs_to_character;
    
    return 0 unless $character;
    
    return 1 if $self->variable('Quantity') > 0 && $character->hit_points_current < $character->hit_points_max;
}

1;