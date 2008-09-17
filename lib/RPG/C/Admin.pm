package RPG::C::Admin;

use strict;
use warnings;
use base 'Catalyst::Controller';

sub auto : Private {
	my ($self, $c) = @_;
		
	return 0 unless $c->session->{player}->admin_user;
}

sub default : Private {
	my ($self, $c) = @_;
	
	$c->forward('/admin/items/edit_item_type');
}

1;