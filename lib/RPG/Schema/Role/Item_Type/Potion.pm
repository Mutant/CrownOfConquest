package RPG::Schema::Role::Item_Type::Potion;

use strict;
use warnings;

use Moose::Role;

requires qw/use label is_usable/;

after 'use' => sub {
    my $self = shift;
    
    my $quantity = $self->variable('Quantity');
    $quantity--;
    if ($quantity == 0) {
        $self->delete;   
    }
    else {
        $self->variable_row('Quantity', $quantity);
    }      
};

sub target {
    return 'self';
}

1;