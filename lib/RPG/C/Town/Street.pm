package RPG::C::Town::Street;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Carp;

sub default : Local {
	my ($self, $c) = @_;
	
	$c->forward('character_list');
}

sub character_list : Private {
	my ($self, $c) = @_;
	
	$c->forward('/town/characterhold/character_list', ['street']);
	
}

sub add_character : Local {
	my ($self, $c) = @_;

	$c->forward('/town/characterhold/add_character', ['street']);
}

sub remove_character : Local {
	my ($self, $c) = @_;
	
	$c->forward('/town/characterhold/remove_character', ['street']);
}

1;