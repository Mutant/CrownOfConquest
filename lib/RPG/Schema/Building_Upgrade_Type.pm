package RPG::Schema::Building_Upgrade_Type;
use base 'DBIx::Class';

use Moose;

with 'RPG::Schema::Role::ResourceConsumer';

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Building_Upgrade_Type');

__PACKAGE__->add_columns( qw/type_id name modifier_per_level modifier_label description
      base_gold_cost base_wood_cost base_iron_cost base_stone_cost base_clay_cost base_turn_cost/ );

__PACKAGE__->set_primary_key('type_id');

sub cost_to_upgrade {
    my $self  = shift;
    my $level = shift;

    return {
        Gold  => $self->base_gold_cost * $level,
        Wood  => $self->base_wood_cost * $level,
        Iron  => $self->base_iron_cost * $level,
        Stone => $self->base_stone_cost * $level,
        Clay  => $self->base_clay_cost * $level,
        Turns => $self->base_turn_cost * $level,
    };
}

sub bonus_label {
    my $self  = shift;
    my $level = shift;

    if ( $self->modifier_per_level ) {
        return "+" . $self->modifier_per_level * $level . " to " . $self->modifier_label;
    }

    if ( $self->name eq 'Market' ) {
        return ( $level * 10 ) . ' - ' . ( $level * 100 ) . ' gold per day';
    }
    elsif ( $self->name eq 'Barracks' ) {
        return ( $level * 5 ) . ' - ' . ( $level * 50 ) . ' xp per day';
    }

    return '';

}

my %UPGRADE_BONUS_MAP = (
    attack_factor      => 'Rune of Attack',
    defence_factor     => 'Rune of Defence',
    resistance_bonuses => 'Rune of Protection',
);

sub upgrade_type_for_bonus {
    my $self       = shift;
    my $bonus_type = shift;

    return $UPGRADE_BONUS_MAP{$bonus_type};
}

sub bonus {
    my $self = shift;

    my %reverse_map = reverse %UPGRADE_BONUS_MAP;

    return $reverse_map{ $self->name };
}

1;
