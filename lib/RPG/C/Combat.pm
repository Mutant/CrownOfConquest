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
	
	my $creature_group = $params->{creature_group} || $c->stash->{party}->cg_opponent;
	unless ($creature_group) {
		$creature_group = $c->model('CreatureGroup')->find(
			{
				creature_group_id => $c->stash->{party}->in_combat_with,
			},
			{
				prefetch => {'creatures' => 'type'},
			},
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

sub fight : Local {
	my ($self, $c) = @_;
	
	# TODO: We should always gave something set in combat_action, because characters will have default
	#  actions (either from the last time they attacked, or from a default for that character). These
	#  defaults are not yet implemented tho, so it's possible combat_action may not be defined.
	
	my $creature_group = $c->model('CreatureGroup')->find(
		{
			creature_group_id => $c->stash->{party}->in_combat_with,
		},
		{
			prefetch => {'creatures' => 'type'},
		},
	);	
	
	my @creatures = $creature_group->creatures;
	
	#while (my ($character_id, $action) = each %{$c->session->{combat_action}}) {
	foreach my $character ($c->stash->{party}->characters) {
		if ($c->session->{combat_action}{$character->id} eq 'Attack') {
			# Choose creature to attack
			# TODO: maybe this should be player selected?
			my $creature = $creatures[int rand($#creatures)];
			$character->attack($creature);
		}
	}
}

1;