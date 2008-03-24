package RPG::C::Town;

use strict;
use warnings;
use base 'Catalyst::Controller';

sub main : Local {
	my ($self, $c) = @_;
	
	return $c->forward('RPG::V::TT',
        [{
            template => 'town/main.html',
			params => {
				town => $c->stash->{party}->location->town,
			},
			return_output => 1,
        }]
    );
}

sub shop_list : Local {
	my ($self, $c) = @_;
	
	$c->stash->{bottom_panel} = $c->forward('RPG::V::TT',
        [{
            template => 'town/shop_list.html',
			params => {
				town => $c->stash->{party}->location->town,
			},
			return_output => 1,
        }]
    );
    
    #warn $c->stash->{bottom_panel};
    
    $c->forward('/party/main');
}

1;