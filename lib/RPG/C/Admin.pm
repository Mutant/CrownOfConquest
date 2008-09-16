package RPG::C::Admin;

use strict;
use warnings;
use base 'Catalyst::Controller';

sub default : Private {
	my ($self, $c) = @_;
	
	$c->forward('/admin/items/edit_item_type');
}

1;