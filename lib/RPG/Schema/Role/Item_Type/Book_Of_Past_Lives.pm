package RPG::Schema::Role::Item_Type::Book_Of_Past_Lives;

use strict;
use warnings;

use Moose::Role;
use Try::Tiny;
use Games::Dice::Advanced;

with 'RPG::Schema::Role::Item_Type::Usable';

sub set_special_vars {
    my $self = shift;
    my @item_variable_params = @_;

    my ($param) = grep { $_->item_variable_name->item_variable_name eq 'Max Level' } @item_variable_params;
        
    my $max_level = 10;
    my $roll = Games::Dice::Advanced->roll('1d100');
    
    if ($roll >= 60) {
        $max_level = 30;
    }
    elsif ($roll >= 20) {
        $max_level = 20;
    }    
    
    $self->add_to_item_variables(
        {
            item_variable_name_id => $param->item_variable_name->id,
            item_variable_value   => $max_level,
        }
    ); 
}

sub display_name {
    my $self = shift;
        
    return "Book of Past Lives (Level " . ($self->variable('Max Level') / 10) . ")";
}

sub label {
    my $self = shift;
    
    return "Read Book of Past Lives";   
}

sub is_usable {
    my $self = shift;
    my $combat = shift // 0;
    my $character = shift;
    
    return 0 if $combat;
        
    return 0 unless $character;
    
    return 0 if $character->level > $self->variable('Max Level');
            
    return 1;
}

sub use {
    my $self = shift;
    my $target = shift;
    
    return unless $self->is_usable(0);
    
    my $character = $self->belongs_to_character;
    
    return unless $character;
    
    $character->character_skills->delete;
    
    $character->skill_points($character->level - 1);
    $character->update;
    
    return RPG::Combat::SpellActionResult->new(
        {
            type => 'book_of_past_lives',
            spell_name => 'read',
            defender => $character,
            attacker => $character,
        }
    );        
}

sub requires_confirmation { 1 }

sub confirmation_message {
    my $self = shift;
        
    my $character = $self->belongs_to_character;    
    
    return "Are you sure you want " . $character->name . " to read the Book? This will reset all " . $character->pronoun('posessive-objective') .
        " skills."; 
}

# Adjust sell price by max level of book
around 'sell_price' => sub {
    my $orig = shift;
    my $self = shift;   
    
    my $price = $self->$orig(@_);
    
    my $price_modifier = RPG::Schema->config->{book_of_past_live_cost_modifiers};
    
    return $price * $price_modifier->{$self->variable('Max Level')};
};

sub target {'self'}

1;