package RPG::C::Combat;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;

sub start : Local {
	my ($self, $c, $params) = @_;
	
	warn Dumper {$params->{creature_group}->creature_summary};
	
	return $c->forward('RPG::V::TT',
        [{
            template => 'combat/main.html',
			params => {
				creature_group => $params->{creature_group},
				creatures_initiated => 1,
			},
			return_output => 1,
        }]
    );		
}

1;