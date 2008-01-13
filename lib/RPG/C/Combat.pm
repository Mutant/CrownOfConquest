package RPG::C::Combat;

use strict;
use warnings;
use base 'Catalyst::Controller';

sub start : Local {
	my ($self, $c, $params) = @_;
	
	$c->forward('RPG::V::TT',
        [{
            template => 'combat/main.html',
			params => {
				creature_group => $params->{creature_group},				
			},
        }]
    );		
}

1;