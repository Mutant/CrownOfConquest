package RPG::C::Combat;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;

use Games::Dice::Advanced;
use List::Util qw(shuffle);

sub start : Local {
	my ($self, $c, $params) = @_;
		
	$c->stash->{party}->in_combat_with($params->{creature_group}->id);
	$c->stash->{party}->update;
	
	$c->forward('/combat/main', $params);
		
}

sub party_attacks : Local {
	my ($self, $c) = @_;
	
	my $creature_group = $c->model('DBIC::CreatureGroup')->search(
		creature_group_id => $c->req->param('creature_group_id'),
		land_id => $c->stash->{party}->land_id,
	)->first;
	
	$c->stash->{creature_group} = $creature_group;
	
	if ($creature_group) {
		$c->stash->{party}->in_combat_with($creature_group->id);
		$c->stash->{party}->update;
		$c->forward('/party/main');
	}
	else {
		$c->error("Couldn't find creature group in party's location.");
	}
		
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
	
	my $character = $c->model('Character')->find($c->req->param('character_id'));
	
	$character->last_combat_action($c->req->param('action'));
	$character->update; 
	
	$c->session->{combat_action_param}{$c->req->param('character_id')} = $c->req->param('action_param');
}

sub fight : Local {
	my ($self, $c) = @_;
	
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
	
	my @combatants = shuffle (@creatures, @characters);
	
	my @combat_messages;
	
	foreach my $combatant (@combatants) {
		next if $combatant->is_dead;
		
		my $action_result;
		if ($combatant->is_character) {
			$action_result = $c->forward('character_action', [$combatant, $creature_group]);
		}
		else {
			$action_result = $c->forward('creature_action', [$combatant, $c->stash->{party}]);			
		}

		if ($action_result) {		
			my ($target, $damage) = @$action_result;
			
			push @combat_messages, {
				attacker => $combatant, 
				defender => $target, 
				damage => $damage || 0,
			};
		}
		
		last if $c->stash->{combat_complete};
	}
		
	push @{ $c->stash->{combat_messages} }, $c->forward('RPG::V::TT',
        [{
            template => 'combat/message.html',
			params => {				
				combat_messages => \@combat_messages,
				combat_complete => $c->stash->{combat_complete},
			},
			return_output => 1,
        }]
    );	
	
	$c->forward('/party/main');
	
}

sub character_action : Private {
	my ($self, $c, $character, $creature_group) = @_;
	
	my @creatures = $creature_group->creatures;
	my %creatures_by_id = map { $_->id => $_ } @creatures;
	
	my ($creature, $damage);
	
	if ($character->last_combat_action eq 'Attack') {
		# If they've selected a target, make sure it's still alive
		my $targetted_creature = $c->session->{combat_action_param}{$character->id};
		if ($targetted_creature && ! $creatures_by_id{$targetted_creature}->is_dead) {
			$creature = $creatures_by_id{$targetted_creature};
		}
		
		# If we don't have a target, choose one randomly
		unless ($creature) {
			do {
				$creature = $creatures[int rand(scalar @creatures)];
			} while ($creature->is_dead);
		}
			
		$damage = $c->forward('attack', [$character, $creature]);
			
		# Store damage done for XP purposes
		$c->session->{damage_done}{$character->id}+=$damage;

		    
	    # If creature is now dead, see if any other creatures are left alive.
	    #  If not, combat is over.
	    if ($creature->is_dead && $creature_group->number_alive == 0) {	    	
	    	# We don't actually do any of the stuff to complete the combat here, so a
	    	#  later action can still display monsters, messages, etc.
	    	$c->stash->{combat_complete} = 1;
	    }
	    
	    return [$creature, $damage];
	}
}

sub creature_action : Private {
	my ($self, $c, $creature, $party) = @_;
		
	my @characters = $party->characters;
	
	my $character;	
	my $count; # XXX this is just here to stop things looping forever if the party is dead
	do {
		my $rand = int rand($#characters + 1);
		$character = $characters[$rand];
	} while ($character->is_dead && $count++ < 20);
		
	my $defending = $character->last_combat_action eq 'Defend' ? 1 : 0;
		
	# Count number of times attacked for XP purposes
	$c->session->{attack_count}{$character->id}++;
			
	my $damage = $c->forward('attack', [$creature, $character, $defending]);
	    
	return [$character, $damage];
}

sub attack : Private {
	my ($self, $c, $attacker, $defender, $defending) = @_;
		
	my $a_roll = int rand RPG->config->{attack_dice_roll}; 
	my $d_roll = int rand RPG->config->{defence_dice_roll};
	
	my $defence_bonus = $defending ? RPG->config->{defend_bonus} : 0; 

	my $aq = $attacker->attack_factor  - $a_roll;	
	my $dq = $defender->defence_factor + $defence_bonus - $d_roll;
	
	#$c->log->debug("Executing attack. Attacker: " . $attacker->name . ", Defender: " . $defender->name);
	
	#$c->log->debug("Attack: Factor: " .  $attacker->attack_factor  . " Roll: $a_roll Quotient: $aq");
	#$c->log->debug("Defence: Factor: " . $defender->defence_factor . " Bonus: $defence_bonus Roll: $d_roll Quotient: $dq");
	
	my $damage = 0;
	
	if ($aq > $dq) {
		# Attack hits
		$damage = (int rand $attacker->damage)+1;
		
		$defender->hit($damage);
		
		$c->log->debug("Damage: $damage");
	}	
	
	return $damage;
}

sub flee : Local {
	my ($self, $c) = @_;
	
	my $rand = int rand 100;
	$c->log->debug("Flee roll: $rand");
	$c->log->debug("Flee chance: " . RPG->config->{flee_chance});
	if ($rand < RPG->config->{flee_chance}) {
	    my $party_location = $c->stash->{party}->location;

		# Get adjacent squares
    	my ($start_point, $end_point) = RPG::Map->surrounds(
			$party_location->x,
			$party_location->y,
			3,
			3,
		);
		
		$c->log->debug(Dumper $start_point, Dumper $end_point);
		
		# Randomly choose a square to flee to
		my ($new_x, $new_y);
		do {
			$new_x = $start_point->{x} + int rand($end_point->{x} - $start_point->{x} + 1);
			$new_y = $start_point->{y} + int rand($end_point->{y} - $start_point->{y} + 1);
		} while ($new_x == $party_location->x && $new_y == $party_location->y);
		
		$c->log->debug("Fleeing to: $new_x, $new_y");
		
		my $land = $c->model('Land')->find({
			x => $new_x,
			y => $new_y,
		});
		
		$c->error("Couldn't find sector: $new_y, $new_y") unless $land;
		
		$c->stash->{party}->land_id($land->id);
		$c->stash->{party}->in_combat_with(undef);
    	# TODO: do we make them use up turns?
    	$c->stash->{party}->update;
    	$c->stash->{party}->discard_changes;
    	
    	$c->forward('/party/main');
	}
	else {
		push @{ $c->stash->{combat_messages} }, 'You were unable to flee.';
		$c->forward('/combat/fight');
	}
}

sub finish : Private {
	my ($self, $c) = @_;	
	
	my @creatures = $c->stash->{creature_group}->creatures;
	
	my $xp;
	
	my $level_aggr = 0;
	foreach my $creature (@creatures) {
		# Generate random modifier between 0.6 and 1.5
		my $rand = (Games::Dice::Advanced->roll('1d10') / 10) + 0.5;
		$xp += int ($creature->type->level * $rand * RPG->config->{xp_multiplier});
		
		$level_aggr += $creature->type->level; 
	}
	my $avg_creature_level = $level_aggr / scalar @creatures;
		
	#my %chars = map { $_->id => $_ } $c->stash->{party}->characters;
	my @characters = $c->stash->{party}->characters;
	
	my $awarded_xp = $c->forward('/combat/distribute_xp', [ $xp, [map { $_->id } @characters] ] );
	
	foreach my $character (@characters) {
		push @{$c->stash->{combat_messages}}, $character->character_name . " gained " . $awarded_xp->{$character->id} . " xp.";
		
		$character->xp($character->xp + $awarded_xp->{$character->id});
		$character->update;
	}
		
	my $gold = scalar @creatures * $avg_creature_level * Games::Dice::Advanced->roll('1d10');
	
	push @{$c->stash->{combat_messages}}, "You find $gold gold";
	$c->stash->{party}->in_combat_with(undef);
	$c->stash->{party}->gold($c->stash->{party}->gold + $gold);
	$c->stash->{party}->update;	
	
	$c->stash->{creature_group}->delete;
}

sub distribute_xp : Private {
	my ($self, $c, $xp, $char_ids) = @_;
	
	#warn Dumper [$xp, $char_ids];
	
	my %awarded_xp;
	
	# Everyone gets 5% to start with
	my $min_xp = int $xp * 0.05; 
	@awarded_xp{@$char_ids} = ($min_xp) x scalar @$char_ids;
	$xp-=$min_xp * scalar @$char_ids;
		
	# Work out total damage, and total attacks made
	my ($total_damage, $total_attacks);
	map { $total_damage+=$_  } values %{$c->session->{damage_done}};
	map { $total_attacks+=$_ } values %{$c->session->{attack_count}}; 

	# Assign each character XP points, up to a max of 30% of the pool
	# (note, they can actually get up to 35%, but we've already given them 5% above)
	# Damage done vs attacks recieved is weighted at 60/40
	my $total_awarded = 0;
	foreach my $char_id (@$char_ids) {
		my ($damage_percent, $attacked_percent) = (0,0);
		
		$damage_percent   = ($c->session->{damage_done}{$char_id} / $total_damage)  * 0.6
			if $total_damage > 0;
		$attacked_percent = ($c->session->{attack_count}{$char_id}/ $total_attacks) * 0.4
			if $total_attacks > 0;
			
				my $total_percent = $damage_percent + $attacked_percent;
		$total_percent = 0.35 if $total_percent > 0.35;
		
		my $xp_awarded = int $xp * $total_percent;
				
		$awarded_xp{$char_id}+=$xp_awarded;
		$total_awarded+=$xp_awarded;
	}
	
	# Figure out how much is left, if any
	$xp -= $total_awarded;
	
	# If there's any XP left, divide it up amongst the party. We round down, so some could be lost
	if ($xp > 0) {
		my $spare_xp = int ($xp / scalar @$char_ids);
		map { $awarded_xp{$_}+=$spare_xp } keys %awarded_xp; 
	}
	
	undef $c->session->{damage_done};
	undef $c->session->{attack_count};
	
	return \%awarded_xp;
}

1;
