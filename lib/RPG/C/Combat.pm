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
	
	if ($c->stash->{combat_complete}) {
		$c->forward('/combat/finish');
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
		},
		{
			prefetch => {'creatures' => 'type'},
		},
	);	
	
	# Later actions might need this
	$c->stash->{creature_group} = $creature_group;
	
	my @creatures = $creature_group->creatures;
	my @characters = $c->stash->{party}->characters;
	
	my @party_messages;
	
	foreach my $character (@characters) {
		next if $character->is_dead;
		
		if ($c->session->{combat_action}{$character->id} eq 'Attack') {
			# Choose creature to attack
			# TODO: maybe this should be player selected?
			my $creature;
			do {
				$creature = $creatures[int rand($#creatures)];
			} while ($creature->is_dead);
			
			my $damage = $c->forward('attack', [$character, $creature]);

			# TODO: might be better as a TT function
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
		    
		    # If creature is now dead, see if any other creatures are left alive.
		    #  If not, combat is over.
		    if ($creature->is_dead && $creature_group->number_alive == 0) {
		    	push @party_messages, "The creatures have been killed!"; # TODO: placeholder
		    	
		    	# We don't actually do any of the stuff to complete the combat here, so a
		    	#  later action can still display monsters, messages, etc.
		    	$c->stash->{combat_complete} = 1;
		    			    	
		    	last;
		    }
		}
	}
	
	unless ($c->stash->{combat_complete}) {	
		foreach my $creature (@creatures) {
			next if $creature->is_dead;
	
			my $character;
			do {
				$character = @characters[int rand($#characters)];
			} while ($character->is_dead);
			
			my $defending = $c->session->{combat_action}{$character->id} eq 'Defend' ? 1 : 0;
				
			my $damage = $c->forward('attack', [$creature, $character, $defending]);
	
			push @party_messages, $c->forward('RPG::V::TT',
		        [{
		            template => 'combat/message.html',
					params => {
						attacker => $creature,
						defender => $character,
						damage => $damage,
					},
					return_output => 1,
		        }]
		    );
		    
		    # TODO: check for dead party
		}
	}
		
	$c->stash->{combat_messages} = \@party_messages;
	
	$c->forward('/party/main');
	
}

sub attack : Private {
	my ($self, $c, $attacker, $defender, $defending) = @_;
		
	my $a_roll = int rand RPG->config->{attack_dice_roll}; 
	my $d_roll = int rand RPG->config->{defence_dice_roll};
	
	my $defence_bonus = $defending ? RPG->config->{defend_bonus} : 0; 

	my $aq = $attacker->attack_factor  - $a_roll;	
	my $dq = $defender->defence_factor + $defence_bonus - $d_roll;
	
	$c->log->debug("Executing attack. Attacker: " . $attacker->name . ", Defender: " . $defender->name);
	
	$c->log->debug("Attack: Factor: " .  $attacker->attack_factor  . " Roll: $a_roll Quotient: $aq");
	$c->log->debug("Defence: Factor: " . $defender->defence_factor . " Bonus: $defence_bonus Roll: $d_roll Quotient: $dq"); 
	
	my $damage = $aq - $dq;
	
	if ($damage > 0) {
		# Attack hits
		$defender->hit($damage);
	}
	
	$c->log->debug("Damage: $damage");
	
	return $damage;
}

sub finish : Private {
	my ($self, $c) = @_;
	
	$c->stash->{party}->in_combat_with(undef);
	$c->stash->{party}->update;
	
	$c->stash->{creature_group}->delete;
	
	# TODO: award xp
}

1;