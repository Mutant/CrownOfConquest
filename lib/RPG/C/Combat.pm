package RPG::C::Combat;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;

sub start : Local {
	my ($self, $c, $params) = @_;
	
	$c->stash->{party}->in_combat_with($params->{creature_group}->id);
	$c->stash->{party}->update;
	
	$c->forward('/combat/main', $params);
		
}

sub default : Private {
	my ($self, $c) = @_;
	
	$c->forward('/combat/main');
}

sub main : Local {
	my ($self, $c, $params) = @_;
	
	my $creature_group = $params->{creature_group};
	unless ($creature_group) {
		$creature_group = $c->model('CreatureGroup')->find(
			creature_group_id => $c->stash->{party}->in_combat_with,
		);
	}	
	
	return $c->forward('RPG::V::TT',
        [{
            template => 'combat/main.html',
			params => {
				creature_group => $creature_group,
				creatures_initiated => $params->{creatures_initiated},				
			},
			return_output => 1,
        }]
    );	
}

sub select_action : Local {
	my ($self, $c) = @_;
	
	$c->session->{combat_action}{$c->req->param('character_id')} = $c->req->param('action'); 
}

1;