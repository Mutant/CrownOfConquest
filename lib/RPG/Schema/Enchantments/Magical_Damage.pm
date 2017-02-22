package RPG::Schema::Enchantments::Magical_Damage;

use Moose::Role;

with 'RPG::Schema::Enchantments::Interface';

use List::Util qw(shuffle);
use RPG::Maths;

my @DAMAGE_TYPES = qw/Fire Ice Poison/;

sub init_enchantment {
    my $self = shift;

    $self->add_to_variables(
        {
            name                => 'Magical Damage Type',
            item_variable_value => ( shuffle @DAMAGE_TYPES )[0],
            item_id             => $self->item_id,
        },
    );

    my $level = RPG::Maths->weighted_random_number( 1 .. 8 );
    $self->add_to_variables(
        {
            name                => 'Magical Damage Level',
            item_variable_value => $level,
            item_id             => $self->item_id,
        },
    );

}

sub is_usable {
    return 0;
}

sub must_be_equipped {
    return 0;
}

sub tooltip {
    my $self = shift;

    return "Inflicts " . $self->variable('Magical Damage Type') . " damage (level " . $self->variable('Magical Damage Level') . ")";
}

sub sell_price_adjustment {
    my $self = shift;

    return 400 + $self->variable('Magical Damage Level') * 225;
}

1;
