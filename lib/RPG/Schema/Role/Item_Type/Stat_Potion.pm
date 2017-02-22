package RPG::Schema::Role::Item_Type::Stat_Potion;

use strict;
use warnings;

use Moose::Role;

with 'RPG::Schema::Role::Item_Type::Potion';

requires 'stat';

sub use {
    my $self = shift;

    return unless $self->is_usable;

    my $character = $self->belongs_to_character;

    return unless $character;

    my $stat = $character->get_column( $self->stat );
    $character->set_column( $self->stat, $stat + 1 );
    $character->calculate_attack_factor;
    $character->calculate_defence_factor;
    $character->update;

    return RPG::Combat::SpellActionResult->new(
        {
            type       => 'potion',
            spell_name => ucfirst $self->stat,
            defender   => $character,
            attacker   => $character,
            effect     => $self->stat,
            damage     => 1,
        }
    );
}

sub label {
    my $self = shift;

    return "Drink Potion of " . ucfirst $self->stat . " (" . $self->variable('Quantity') . ')';
}

sub is_usable {
    my $self = shift;
    my $combat = shift // 0;

    return 0 if $combat;

    return 1 if $self->variable('Quantity') > 0;
}

1;
