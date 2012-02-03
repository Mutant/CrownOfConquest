package RPG::Schema::Building_Upgrade_Type;
use base 'DBIx::Class';
use strict;
use warnings;

use feature 'switch';

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Building_Upgrade_Type');

__PACKAGE__->add_columns(qw/type_id name modifier_per_level modifier_label description 
    base_gold_cost base_wood_cost base_iron_cost base_stone_cost base_clay_cost base_turn_cost/);
    
__PACKAGE__->set_primary_key('type_id');

sub cost_to_upgrade {
    my $self = shift;
    my $level = shift;
    
    return {
        Gold  => $self->base_gold_cost  * $level,
        Wood  => $self->base_wood_cost  * $level,
        Iron  => $self->base_iron_cost  * $level,
        Stone => $self->base_stone_cost * $level,
        Clay  => $self->base_clay_cost  * $level,
        Turns => $self->base_turn_cost  * $level,
    };
}

sub bonus_label {
    my $self = shift;
    my $level = shift;

    if ($self->modifier_per_level) {
        return "+" . $self->modifier_per_level * $level . " to " . $self->modifier_label; 
    }
    
    return '';

}

1;
