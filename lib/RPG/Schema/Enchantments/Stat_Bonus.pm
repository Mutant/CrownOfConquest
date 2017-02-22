package RPG::Schema::Enchantments::Stat_Bonus;

use Moose::Role;

with 'RPG::Schema::Enchantments::Interface';

use List::Util qw(shuffle);
use RPG::Maths;

use RPG::Schema::Character;

sub init_enchantment {
    my $self = shift;

    my @enchantments = $self->item->item_enchantments;
    my %stats_already_used;
    foreach my $enchantment (@enchantments) {
        if ( $enchantment->variable("Stat Bonus") ) {
            $stats_already_used{ $enchantment->variable("Stat Bonus") } = 1;
        }
    }

    my @stats = RPG::Schema::Character->long_stats();

    my $stat = ( shuffle grep { !$stats_already_used{$_} } @stats )[0];

    $self->add_to_variables(
        {
            name                => 'Stat Bonus',
            item_variable_value => $stat,
            item_id             => $self->item_id,
        },
    );

    my $bonus = RPG::Maths->weighted_random_number( 1 .. 5 );
    $self->add_to_variables(
        {
            name                => 'Bonus',
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

    return '+' . $self->variable('Bonus') . ' to ' . ucfirst $self->variable("Stat Bonus");
}

sub sell_price_adjustment {
    my $self = shift;

    return 265 * $self->variable('Bonus');
}

1;
