package RPG::C::Sewer;

use strict;
use warnings;
use base 'Catalyst::Controller';

sub move_to : Local {
	my ( $self, $c ) = @_;

	$c->forward( '/dungeon/move_to' );
}

sub check_for_creature_move : Private {
    my ( $self, $c, $current_location ) = @_;
    
    $c->forward('/dungeon/check_for_creature_move', [$current_location]);
}

sub exit : Private {
	my ( $self, $c, $turns ) = @_;

	$c->forward( '/dungeon/exit', [$turns] );
}

1;