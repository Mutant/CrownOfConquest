package RPG::C::Town::Inn;

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
	
	$c->forward('/town/characterhold/character_list', ['inn']);
	
}

sub add_character : Local {
	my ($self, $c) = @_;

	$c->forward('/town/characterhold/add_character', ['inn']);
}

sub remove_character : Local {
	my ($self, $c) = @_;
	
	$c->forward('/town/characterhold/remove_character', ['inn']);
}

1;