package RPG::Schema::Role::Item_Type::Scroll;

use strict;
use warnings;

use Moose::Role;

with 'RPG::Schema::Role::Item_Type::Usable';

use List::Util qw(shuffle);

sub display_name {
    my $self = shift;
        
    return "Scroll of " . $self->spell->spell_name;
}

sub set_special_vars {
    my $self = shift;
    my @item_variable_params = @_;

    my ($param) = grep { $_->item_variable_name->item_variable_name eq 'Spell' } @item_variable_params;
        
    my @spells = $self->result_source->schema->resultset('Spell')->search(
        {
            hidden => 0,
        }
    );
    
    my $spell = (shuffle @spells)[0];
    
    $self->add_to_item_variables(
        {
            item_variable_name_id => $param->item_variable_name->id,
            item_variable_value   => $spell->spell_name,
        }
    ); 
}

sub spell {
    my $self = shift;
    
    my $spell = $self->result_source->schema->resultset('Spell')->find(
        {
            spell_name => $self->variable('Spell'),
        }
    );
    
    return $spell;
}

sub use {
    my $self = shift;
    my $target = shift;
        
    my $character = $self->belongs_to_character;
    
    return unless $character;    
    
    my $spell = $self->spell;
    
    return $spell->cast_from_action($character, $target);
}

sub label {
    my $self = shift;
    
    return "Use Scroll of " . $self->spell->spell_name;   
}

sub is_usable {
    my $self = shift;
    my $combat = shift // 0;
    
    return $combat ? $self->spell->combat : $self->spell->non_combat;    
}

sub target {
    my $self = shift;
    
    return $self->spell->target;   
}

around 'sell_price' => sub {
    my $orig = shift;
    my $self = shift;
    
    my $price = $self->$orig(@_);
    
    $price *= $self->spell->points;
    
    return $price;  
};

1;
