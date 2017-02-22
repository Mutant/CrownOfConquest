package RPG::Schema::Enchantments::Spell_Casts_Per_Day;

use Moose::Role;

with 'RPG::Schema::Enchantments::Interface';

use RPG::Maths;

sub init_enchantment {
    my $self = shift;

    my $spell = $self->result_source->schema->resultset('Spell')->random(
        exclude => 'Detonate',
    );
    $self->add_to_variables(
        {
            name                => 'Spell',
            item_variable_value => $spell->spell_name,
            item_id             => $self->item_id,
        },
    );

    my $casts_per_day = RPG::Maths->weighted_random_number( 1 .. 10 );
    $self->add_to_variables(
        {
            name                => 'Casts Per Day',
            item_variable_value => $casts_per_day,
            max_value           => $casts_per_day,
            item_id             => $self->item_id,
        },
    );

    my $spell_level = RPG::Maths->weighted_random_number( 1 .. 20 );
    $self->add_to_variables(
        {
            name                => 'Spell Level',
            item_variable_value => $spell_level,
            max_value           => $spell_level,
            item_id             => $self->item_id,
        },
    );
}

sub is_usable {
    my $self   = shift;
    my $combat = shift;

    return 0 if $self->variable('Casts Per Day') <= 0;

    return 1 if $combat && $self->spell->combat;

    return 1 if !$combat && $self->spell->non_combat;

    return 0;
}

sub must_be_equipped {
    return 1;
}

sub label {
    my $self = shift;

    return $self->item->display_name . " (" . $self->variable('Spell') . " (" .
      $self->variable('Casts Per Day') . "))";
}

sub tooltip {
    my $self = shift;

    my $casts_var = $self->variable_row('Casts Per Day');

    confess "Can't find casts per day var" unless $casts_var;

    my $times = $casts_var->max_value . ' times';
    if ( $casts_var->max_value == 1 ) {
        $times = 'once';
    }
    elsif ( $casts_var->max_value == 2 ) {
        $times = 'twice';
    }

    return "Cast " . $self->variable('Spell') . ' (level ' . $self->variable('Spell Level') . ') ' .
      "$times per day";
}

sub target {
    my $self = shift;

    return $self->spell->target;
}

sub spell {
    my $self = shift;

    return $self->result_source->schema->resultset('Spell')->find(
        {
            spell_name => $self->variable('Spell'),
        },
    );
}

sub use {
    my $self = shift;
    my $target = shift || confess "Target not supplied";

    my $casts_per_days = $self->variable_row('Casts Per Day');

    confess "No casts left today" unless $casts_per_days->item_variable_value > 0;

    my $result = $self->spell->cast_from_action( $self->item->belongs_to_character, $target, $self->variable('Spell Level') );

    $casts_per_days->decrement_item_variable_value;
    $casts_per_days->update;

    return $result;
}

sub new_day {
    my $self = shift;

    my $casts_per_days = $self->variable_row('Casts Per Day');
    $casts_per_days->item_variable_value( $casts_per_days->max_value );
    $casts_per_days->update;

    return;
}

sub sell_price_adjustment {
    my $self = shift;

    my $step = ( $self->variable('Casts Per Day') + $self->variable('Spell Level') ) * $self->spell->points * 40;

    return 120 + $step;
}

1;
