package RPG::Schema::Role::Item_Type::Potion_of_Clarity;

use strict;
use warnings;

use Moose::Role;

with 'RPG::Schema::Role::Item_Type::Potion';

use RPG::Combat::SpellActionResult;

sub use {
    my $self = shift;
    
    return unless $self->is_usable;
    
    my $character = $self->belongs_to_character;
    
    return unless $character;
    
    my $spell_count = $character->rememorise_spells;
    
    return RPG::Combat::SpellActionResult->new(
        {
            type => 'potion',
            spell_name => 'clarity',
            defender => $character,
            attacker => $character,
            effect => "remembered $spell_count spells",
        }
    );
}

sub label {
    my $self = shift;
    
    return "Drink Potion of Clarity (" . $self->variable('Quantity') . ')';   
}

sub is_usable {
    my $self = shift;
    
    my $character = $self->belongs_to_character;
    
    return 0 unless $character;

    return 1 if $character->is_spell_caster && $self->variable('Quantity') > 0;
}

1;