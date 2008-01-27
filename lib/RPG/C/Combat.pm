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
	
	my $creature_group = $params->{creature_group} || $c->stash->{creature_group};
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
				combat_messages => $c->stash->{combat_messages},
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
			#'creatures.hit_points_current' => {'>',0},
		},
		{
			prefetch => {'creatures' => 'type'},
		},
	);	
	
	my @creatures = $creature_group->creatures;
	
	my @party_messages;
	
	foreach my $character ($c->stash->{party}->characters) {
		next if $character->is_dead;
		
		if ($c->session->{combat_action}{$character->id} eq 'Attack') {
			# Choose creature to attack
			# TODO: maybe this should be player selected?
			my $creature;
			do {
				$creature = $creatures[int rand($#creatures)];
			} while ($creature->is_dead);
			
			my $damage = $c->forward('attack', [$character, $creature]);

			push @party_messages, $c->forward('RPG::V::TT',
		        [{
		            template => 'combat/message.html',
					params => {
						attacker => $character,
						defender => $creature,
						damage => $damage,
					},
					return_output => 1,
		        }]
		    );			
		}
	}
		
	$c->stash->{combat_messages} = \@party_messages;
	
	$c->stash->{creature_group} = $creature_group;
	
	$c->forward('/party/main');
	
}

sub attack : Private {
	my ($self, $c, $attacker, $defender) = @_;
		
	my $a_roll = int rand RPG->config->{attack_dice_roll}; 
	my $d_roll = int rand RPG->config->{defence_dice_roll};

	my $aq = $attacker->attack_factor  - $a_roll;	
	my $dq = $defender->defence_factor - $d_roll;
	
	$c->log->debug("Executing attack. Attacker: " . $attacker->name . ", Defender: " . $defender->name);
	
	$c->log->debug("Attack: Factor: " .  $attacker->attack_factor  . " Roll: $a_roll Quotient: $aq");
	$c->log->debug("Defence: Factor: " . $defender->defence_factor . " Roll: $d_roll Quotient: $dq"); 
	
	my $damage = $aq - $dq;
	
	if ($damage > 0) {
		# Attack hits
		$defender->hit($damage);
	}
	
	$c->log->debug("Damage: $damage");
	
	return $damage;
}

1;