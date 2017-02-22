package RPG::Schema::Enchantments::Critical_Hit_Bonus;

use Moose::Role;

with 'RPG::Schema::Enchantments::Interface';

use RPG::Maths;

sub init_enchantment {
    my $self = shift;

    my $bonus = RPG::Maths->weighted_random_number( 1 .. 5 );

    $self->add_to_variables(
        {
            name                => 'Critical Hit Bonus',
            item_variable_value => $bonus,
            item_id             => $self->item_id,
        },
    );
}

sub is_usable {
    return 0;
}

sub must_be_equipped {
    return 1;
}

sub tooltip {
    my $self = shift;

    return '+' . $self->variable('Critical Hit Bonus') . '% Critical Hit Chance';
}

sub sell_price_adjustment {
    my $self = shift;

    return $self->variable('Critical Hit Bonus') * 70;
}

1;
