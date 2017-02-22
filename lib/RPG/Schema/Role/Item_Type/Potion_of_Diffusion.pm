package RPG::Schema::Role::Item_Type::Potion_of_Diffusion;

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

    my @effects = $character->character_effects;
    foreach my $effect (@effects) {
        if ( $effect->effect->modifier < 0 ) {
            $effect->effect->delete;
        }
    }

    return RPG::Combat::SpellActionResult->new(
        {
            type       => 'potion',
            spell_name => 'diffusion',
            defender   => $character,
            attacker   => $character,
            effect     => 'dispelled negative effects',
        }
    );
}

sub label {
    my $self = shift;

    return "Drink Potion of Diffusion (" . $self->variable('Quantity') . ')';
}

sub is_usable {
    my $self      = shift;
    my $combat    = shift;
    my $character = shift;

    return 0 unless $character;

    my $negative_effect_count = $character->search_related(
        'character_effects',
        {
            'effect.modifier' => { '<', 0 },
        },
        {
            join => 'effect',
        }
    )->count;

    return 1 if $negative_effect_count > 0 && $self->variable('Quantity') > 0;
}

1;
