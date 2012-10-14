package RPG::Schema::Role::Item_Type::Usable;

use strict;
use warnings;

use Moose::Role;

requires qw/use label is_usable target/;

after 'use' => sub {
    my $self = shift;
    
    my $quantity = $self->variable('Quantity');
    $quantity--;
    if ($quantity <= 0) {
        my $character = $self->belongs_to_character;
        $character->remove_item_from_grid($self);
        $self->delete;   
    }
    else {
        $self->variable_row('Quantity', $quantity);
    }      
};

around 'is_usable' => sub {
    my $orig = shift;
    my $self = shift;
    
    my $combat = shift;
    my $character = shift // $self->belongs_to_character;
    
    return $self->$orig($combat, $character);
};

1;