package RPG::C::Combat;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use Carp;

use Games::Dice::Advanced;
use List::Util qw(shuffle);
use DateTime;

sub auto : Private {
	my ($self, $c) = @_;

	# Load combat_log into stash (if we're in combat)
	if ($c->stash->{party}->in_combat_with) {
		$c->stash->{combat_log} = $c->model('DBIC::Combat_Log')->find(
			{
				party_id => $c->stash->{party}->id,
				creature_group_id => $c->stash->{party}->in_combat_with,
				land_id => $c->stash->{party_location}->id,
				encounter_ended => undef,
			},
		);
		
		unless ($c->stash->{combat_log}) {
			$c->error('No combat log found for in progress combat');
			return 0;	
		}
	}
	
	return 1;
}

sub end : Private {
	my ($self, $c) = @_;
	
	# Save any changes to the combat log
    $c->stash->{combat_log}->update if $c->stash->{combat_log};	
}

# Check to see if creatures attack party (if there are any in their current sector)
sub check_for_attack : Local {
	my ($self, $c, $new_land) = @_;
	
	# See if party is in same location as a creature
	my $creature_group = $c->model('DBIC::CreatureGroup')->find(
        {
            'location.x' => $new_land->x,
            'location.y' => $new_land->y,
        },
        {
            prefetch => [('location', {'creatures' => 'type'})],
        },
    );
		    
    # If there are creatures here, check to see if we go straight into a combat
    if ($creature_group) {
    	$c->stash->{creature_group} = $creature_group;
	    		    	
    	if ($creature_group->initiate_combat($c->stash->{party})) {
        	$c->stash->{party}->in_combat_with($creature_group->id);
        	$c->stash->{party}->update;
        	$c->stash->{creatures_initiated} = 1;
        	
        	$c->forward('create_combat_log', [$creature_group, 'creatures']);
        	
        	return $creature_group;    
    	}
   	}	
}

sub party_attacks : Local {
	my ($self, $c) = @_;
	
	my $creature_group = $c->model('DBIC::CreatureGroup')->find(
		{
			creature_group_id => $c->req->param('creature_group_id'),
			land_id => $c->stash->{party}->land_id,
		},
		{
			prefetch => {'creatures' => 'type'},
		},
	);
	
	$c->stash->{creature_group} = $creature_group;
	
	if ($creature_group) {
		$c->stash->{party}->in_combat_with($creature_group->id);
		$c->stash->{party}->update;
		
		$c->forward('create_combat_log', [$creature_group, 'party']);
		
		
		$c->forward('/panel/refresh', ['messages', 'party']);
	}
	else {
		$c->error("Couldn't find creature group in party's location.");
	}		
}

sub create_combat_log : Private {
	my ($self, $c, $creature_group, $initiated_by) = @_;

	my $current_day = $c->model('DBIC::Day')->find(
		{			
		},
		{
			select => {max => 'day_number'},
			as => 'current_day'
		},
	)->get_column('current_day');	
		
	$c->stash->{combat_log} = $c->model('DBIC::Combat_Log')->create(
		{
			party_id => $c->stash->{party}->id,
			creature_group_id => $creature_group->id,
			land_id  => $creature_group->location->id,
			encounter_started => DateTime->now(),
			combat_initiated_by => $initiated_by,
			party_level => $c->stash->{party}->level,
			creature_group_level => $creature_group->level,
			game_day => $current_day,
		},
	);	
}

sub main : Local {
	my ($self, $c) = @_;
	
	my $creature_group = $c->stash->{creature_group};
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
				creatures_initiated => $c->stash->{creatures_initiated},
				combat_messages => $c->stash->{combat_messages},
				combat_complete => $c->stash->{combat_complete},
				party_dead => $c->stash->{party}->defunct ? 1 : 0,
			},
			return_output => 1,
        }]
    );
}

sub select_action : Local {
	my ($self, $c) = @_;
	
	my $character = $c->model('DBIC::Character')->find($c->req->param('character_id'));
	
	$character->last_combat_action($c->req->param('action'));
	$character->update; 
	
	# Remove empty strings
	my @action_params = grep { $_ ne '' } $c->req->param('action_param');
		
	if (! @action_params) {
		delete $c->session->{combat_action_param}{$c->req->param('character_id')};
	}
	elsif (scalar @action_params == 1) {
		$c->session->{combat_action_param}{$c->req->param('character_id')} = $action_params[0];
	}
	else {
		$c->session->{combat_action_param}{$c->req->param('character_id')} = \@action_params;
	}	
	
	$c->forward('/panel/refresh', ['messages']);
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
	
	# See if the creatures want to flee
	if ($creature_group->level < $c->stash->{party}->level) {
		my $chance_of_fleeing = ($c->stash->{party}->level - $creature_group->level) * $c->config->{chance_creatures_flee_per_level_diff};		
		
		$c->log->debug("Chance of creatures fleeing: $chance_of_fleeing");
		
		if ($chance_of_fleeing >= Games::Dice::Advanced->roll('1d100')) {
			$c->detach('creatures_flee');
		}
	}
	
	my @creatures = $creature_group->creatures;
	my @characters = $c->stash->{party}->characters;
		
	$c->forward('process_effects');
	
	# Get list of combatants, modified for changes in attack frequency, and radomised in order
	my $combatants = $c->forward('get_combatant_list', [\@characters, \@creatures]);
	
	my @combat_messages;
	
	foreach my $combatant (@$combatants) {
		next if $combatant->is_dead;
		
		my $action_result;
		if ($combatant->is_character) {
			$action_result = $c->forward('character_action', [$combatant, $creature_group]);
		}
		else {
			$action_result = $c->forward('creature_action', [$combatant, $c->stash->{party}]);			
		}

		if ($action_result) {
			if (ref $action_result) {
				my ($target, $damage) = @$action_result;
				
				push @combat_messages, {
					attacker => $combatant, 
					defender => $target, 
					defender_killed => $target->is_dead,
					damage => $damage || 0,
				};
			}
			else {
				push @combat_messages, $action_result;
			}
		}
		
		last if $c->stash->{combat_complete} || $c->stash->{party}->defunct;
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
    
    $c->stash->{party}->turns($c->stash->{party}->turns - 1);
    $c->stash->{party}->update;
    
    $c->stash->{combat_log}->rounds($c->stash->{combat_log}->rounds+1);
  
	$c->forward('/panel/refresh', ['messages', 'party', 'party_status']);
}

sub character_action : Private {
	my ($self, $c, $character, $creature_group) = @_;	
	
	my ($creature, $damage);
	
	my %creatures = map { $_->id => $_ } $creature_group->creatures;
	
	if ($character->last_combat_action eq 'Attack') {
		# If they've selected a target, make sure it's still alive
		my $targetted_creature = $c->session->{combat_action_param}{$character->id};
		#warn Dumper $targetted_creature;
		if ($targetted_creature && $creatures{$targetted_creature} && ! $creatures{$targetted_creature}->is_dead) {
			$creature = $creatures{$targetted_creature};
		}
		
		# If we don't have a target, choose one randomly
		unless ($creature) {
			do {
				my @ids = shuffle keys %creatures;
				$creature = $creatures{$ids[0]};				
			} while ($creature->is_dead);
		}
			
		$damage = $c->forward('attack', [$character, $creature]);
			
		# Store damage done for XP purposes
		$c->session->{damage_done}{$character->id}+=$damage unless ref $damage;
		    
	    # If creature is now dead, see if any other creatures are left alive.
	    #  If not, combat is over.
	    if ($creature->is_dead && $creature_group->number_alive == 0) {	    	
	    	# We don't actually do any of the stuff to complete the combat here, so a
	    	#  later action can still display monsters, messages, etc.
	    	$c->stash->{combat_log}->outcome('party_won');
	    	$c->stash->{combat_log}->encounter_ended(DateTime->now());
	    	
	    	$c->stash->{combat_complete} = 1;
	    }
	    
	    return [$creature, $damage];
	}
	elsif ($character->last_combat_action eq 'Cast') {		
		my $message = $c->forward('/magic/cast',
			[
				$character,
				$c->session->{combat_action_param}{$character->id}[0],
				$c->session->{combat_action_param}{$character->id}[1],
			],
		);
		
		$character->last_combat_action('Defend');
		$character->update;
		
		$c->stash->{combat_log}->spells_cast($c->stash->{combat_log}->spells_cast+1);
		
		return $message;
	}
}

sub creature_action : Private {
	my ($self, $c, $creature, $party) = @_;
		
	my @characters = sort { $a->party_order <=> $b->party_order } $party->characters;
	@characters = grep { ! $_->is_dead } @characters; # Get rid of corpses 
	
	# Figure out whether creature will target front or back rank
	my $rank_pos = $c->stash->{party}->rank_separator_position;
	unless ($rank_pos == scalar @characters) {
		my $rank_roll = Games::Dice::Advanced->roll('1d100');
		if ($rank_roll <= RPG->config->{front_rank_attack_chance}) {
			# Remove everything but front rank
			splice @characters, $rank_pos;
		}
		else {
			# Remove everything but back rank
			splice @characters, 0, $rank_pos;
		}
	}
	
	# Go back to original list if there's nothing in characters (i.e. there are only dead (or no) chars in this rank)
	@characters = $party->characters unless scalar @characters > 0;
	 
	my $character;
	do {
		my $rand = int rand($#characters + 1);
		$character = $characters[$rand];
	} while ($character->is_dead);
		
	my $defending = $character->last_combat_action eq 'Defend' ? 1 : 0;
		
	# Count number of times attacked for XP purposes
	$c->session->{attack_count}{$character->id}++;
			
	my $damage = $c->forward('attack', [$creature, $character, $defending]);
	    
	# Check for wiped out party
	if ($character->is_dead && $party->number_alive == 0) {
	   	$c->stash->{combat_log}->outcome('creatures_won');
	   	$c->stash->{combat_log}->encounter_ended(DateTime->now());
	   	
	   	$party->defunct(DateTime->now());
	   	$party->update;
	    	
	   	#$c->stash->{party_dead} = 1;
	}
	    
	return [$character, $damage];
}

sub get_combatant_list : Private {
	my ($self, $c, $characters, $creatures) = @_;
		
	my @combatants;
	foreach my $character (@$characters) {		
		my @attack_history = @{$c->session->{attack_history}{character}{$character->id}}
			if $c->session->{attack_history}{character}{$character->id};
			
		my $number_of_attacks = $character->number_of_attacks(@attack_history);
		
		push @attack_history, $number_of_attacks;	
		
		$c->session->{attack_history}{character}{$character->id} = \@attack_history;		
		
		for (1..$number_of_attacks) {
			push @combatants, $character;
		}
	}
	
	foreach my $creature (@$creatures) {
		my @attack_history = @{$c->session->{attack_history}{creature}{$creature->id}}
			if $c->session->{attack_history}{creature}{$creature->id};	

		my $attack_allowed = $creature->is_attack_allowed(@attack_history);
	
		push @attack_history, $attack_allowed;	
		
		$c->session->{attack_history}{creature}{$creature->id} = \@attack_history;
		
		push @combatants, $creature if $attack_allowed;
	}
	
	@combatants = shuffle @combatants;
	
	return \@combatants;		
}

sub attack : Private {
	my ($self, $c, $attacker, $defender, $defending) = @_;

	if (my $attack_error = $attacker->execute_attack) {
		$c->log->debug("Attacker " . $attacker->name . " wasn't able to attack defender " . $defender->name . " Error:" . Dumper $attack_error);
		return $attack_error;
	}
		
	my $a_roll = Games::Dice::Advanced->roll('1d' . RPG->config->{attack_dice_roll}); 
	my $d_roll = Games::Dice::Advanced->roll('1d' . RPG->config->{defence_dice_roll});
	
	my $defence_bonus = $defending ? RPG->config->{defend_bonus} : 0;
	
	my $af = $attacker->attack_factor;
	my $df = $defender->defence_factor;
	
	my $aq = $af - $a_roll;	
	my $dq = $df + $defence_bonus - $d_roll;
	
	$c->log->debug("Executing attack. Attacker: " . $attacker->name . ", Defender: " . $defender->name);
	
	$c->log->debug("Attack:  Factor: $af Roll: $a_roll  Quotient: $aq");
	$c->log->debug("Defence: Factor: $df Roll: $d_roll  Quotient: $dq Bonus: $defence_bonus ");
	
	my $damage = 0;
	
	if ($aq > $dq) {
		# Attack hits
		$damage = (int rand $attacker->damage)+1;
		
		$defender->hit($damage);
		
		# Record damage in combat log
		my $damage_col = $attacker->is_character ? 'total_character_damage' : 'total_creature_damage';
		$c->stash->{combat_log}->set_column($damage_col, $c->stash->{combat_log}->get_column($damage_col) + $damage);
		
		if ($defender->is_dead) {
			my $death_col = $defender->is_character ? 'character_deaths' : 'creature_deaths';	
			$c->stash->{combat_log}->set_column($death_col, $c->stash->{combat_log}->get_column($death_col) + 1);
		} 
		
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
		my $land = $c->forward('get_sector_to_flee_to');	
		
		my $party = $c->stash->{party};
		
		$party->land_id($land->id);
		$party->in_combat_with(undef);
		
		# Still costs them turns to move (but they can do it even if they don't have enough turns left)
		$party->turns($c->stash->{party}->turns - $land->movement_cost($party->movement_factor));
		$party->turns(0) if $party->turns < 0;		

    	$party->update;
    	
    	# Refresh stash
    	$c->stash->{party} = $party; 	
    	$c->stash->{party_location} = $land;
    	
    	$c->stash->{messages} = "You got away!";
    	
    	$c->stash->{combat_log}->outcome('party_fled');
    	$c->stash->{combat_log}->encounter_ended(DateTime->now());
    	
    	$c->forward('/panel/refresh', ['messages', 'map', 'party', 'party_status']);
	}
	else {
		push @{ $c->stash->{combat_messages} }, 'You were unable to flee.';
		$c->forward('/combat/fight');
	}
}

sub creatures_flee : Private {
	my ($self, $c) = @_;
	
	my $land = $c->forward('get_sector_to_flee_to', [1]);
	
	$c->stash->{creature_group}->land_id($land->id);
	$c->stash->{creature_group}->update;
	undef $c->stash->{creature_group};
		
	$c->stash->{party}->in_combat_with(undef);
	$c->stash->{party}->update;
	
	$c->stash->{messages} = "The creatures fled!";
	
	$c->stash->{combat_log}->outcome('creatures_fled');
	$c->stash->{combat_log}->encounter_ended(DateTime->now());
	
	$c->forward('/panel/refresh', ['messages', 'party', 'party_status']);
}

# For the party or the creatures
sub get_sector_to_flee_to : Private {
	my ($self, $c, $check_for_creature_group) = @_;
	
	my $party_location = $c->stash->{party}->location;
	
	my @sectors_to_flee_to;
	my $range = 3;
	
	while (! @sectors_to_flee_to) { 
		my ($start_point, $end_point) = RPG::Map->surrounds(
			$party_location->x,
			$party_location->y,
			$range,
			$range,
		);
		
		my %params;
		$params{'creature_group.creature_group_id'} = undef
			if $check_for_creature_group;
		
		@sectors_to_flee_to = $c->model('Land')->search(
			{
				%params,
				x => {'>=', $start_point->{x}, '<=', $end_point->{x}, '!=', $party_location->x},
				y => {'>=', $start_point->{y}, '<=', $end_point->{y}, '!=', $party_location->y}, 
			},
			{
				join => 'creature_group',
			},
		);
		
		$range++;
	}
	
	@sectors_to_flee_to = shuffle @sectors_to_flee_to;
	my $land = shift @sectors_to_flee_to;
	
	$c->log->debug("Fleeing to " . $land->x . ", " . $land->y);
	
	return $land;
}

sub finish : Private {
	my ($self, $c) = @_;	
	
	my @creatures = $c->stash->{creature_group}->creatures;
	
	undef $c->session->{combat_action_param};
	undef $c->session->{rounds_since_last_double_attack};
	
	my $xp;
	
	foreach my $creature (@creatures) {
		# Generate random modifier between 0.6 and 1.5
		my $rand = (Games::Dice::Advanced->roll('1d10') / 10) + 0.5;
		$xp += int ($creature->type->level * $rand * RPG->config->{xp_multiplier});		 
	}

	my $avg_creature_level = $c->stash->{creature_group}->level;
	
	my @characters = $c->stash->{party}->characters;
	
	my $awarded_xp = $c->forward('/combat/distribute_xp', [ $xp, [map { $_->is_dead ? () : $_->id } @characters] ] );
	
	foreach my $character (@characters) {
		next if $character->is_dead;
		
		my $level_up_details = $character->xp($character->xp + $awarded_xp->{$character->id});
		
		push @{$c->stash->{combat_messages}}, $c->forward('RPG::V::TT',
	        [{
	            template => 'party/xp_gain.html',
				params => {				
					character => $character,
					xp_awarded => $awarded_xp->{$character->id},
					level_up_details => $level_up_details,
				},
				return_output => 1,
	        }]
	    );
		
		$character->update;
	}
	my $gold = scalar(@creatures) * $avg_creature_level * Games::Dice::Advanced->roll('2d8');
	
	push @{$c->stash->{combat_messages}}, "You find $gold gold";
	
	$c->forward('check_for_item_found', [\@characters, $avg_creature_level]);

	$c->stash->{party}->in_combat_with(undef);
	$c->stash->{party}->gold($c->stash->{party}->gold + $gold);
	$c->stash->{party}->update;
	
	$c->stash->{combat_log}->gold_found($gold);
	$c->stash->{combat_log}->xp_awarded($xp);
	$c->stash->{combat_log}->encounter_ended(DateTime->now());
	
	# Remove character effects from this combat
	# TODO: needs to be done after fleeing...
    foreach my $character ($c->stash->{party}->characters) {
    	foreach my $effect ($character->character_effects) {
    		$effect->delete if $effect->effect->combat;	
    	}
    }
    
    # Check for state of quests
    my $messages = $c->forward('/quest/check_action', ['creature_group_killed']);
    push @{$c->stash->{combat_messages}}, @$messages; 
    
	$c->stash->{creature_group}->land_id(undef);
	$c->stash->{creature_group}->update;
	
	$c->stash->{party_location}->creature_threat($c->stash->{party_location}->creature_threat - 5);
	$c->stash->{party_location}->update;
}

sub check_for_item_found : Private {
	my ($self, $c, $characters, $avg_creature_level) = @_;
	
	# See if party find an item
	if (Games::Dice::Advanced->roll('1d100') <= $avg_creature_level * $c->config->{chance_to_find_item}) {
		my $prevalence_roll = Games::Dice::Advanced->roll('1d100');
		
		# Get item_types within the prevalance roll
		my @item_types = shuffle $c->model('DBIC::Item_Type')->search(
			{
				prevalence => {'>=', $prevalence_roll},
			}
		);
		
		my $item_type = shift @item_types;
		
		# Choose a random character to find it
		my $finder;
		while (! $finder || $finder->is_dead) {
			$finder = (shuffle @$characters)[0];
		}
		
		# Create the item
		my $item = $c->model('Items')->create(
			{
				item_type_id => $item_type->id,
				character_id => $finder->id,				
			},
		);
		
		push @{$c->stash->{combat_messages}}, $finder->character_name . " found a " . $item->display_name;
	}	
}

sub distribute_xp : Private {
	my ($self, $c, $xp, $char_ids) = @_;
	
	#warn Dumper [$xp, $char_ids];
	
	my %awarded_xp;
	
	# Everyone gets 10% to start with
	my $min_xp = int $xp * 0.10; 
	@awarded_xp{@$char_ids} = ($min_xp) x scalar @$char_ids;
	$xp-=$min_xp * scalar @$char_ids;
		
	# Work out total damage, and total attacks made
	my ($total_damage, $total_attacks);
	map { $total_damage+=$_  } values %{$c->session->{damage_done}};
	map { $total_attacks+=$_ } values %{$c->session->{attack_count}}; 

#warn "total dam: $total_damage\n";
#warn "total att: $total_attacks\n";

	# Assign each character XP points, up to a max of 30% of the pool
	# (note, they can actually get up to 35%, but we've already given them 5% above)
	# Damage done vs attacks recieved is weighted at 60/40
	my $total_awarded = 0;
	foreach my $char_id (@$char_ids) {
		my ($damage_percent, $attacked_percent) = (0,0);

		#warn $char_id;
		
		#warn "dam_done:  " . $c->session->{damage_done}{$char_id};
		#warn "att_count: " . $c->session->{attack_count}{$char_id};
		
		$damage_percent   = (($c->session->{damage_done}{$char_id} || 0) / $total_damage)   * 0.6
			if $total_damage > 0;
		$attacked_percent = (($c->session->{attack_count}{$char_id} || 0) / $total_attacks) * 0.4
			if $total_attacks > 0;
			
		#warn "dam: " . $damage_percent;
		#warn "att: " . $attacked_percent;
			
		my $total_percent = $damage_percent + $attacked_percent;
		$total_percent = 0.35 if $total_percent > 0.35;
		
		#warn $total_percent;
		
		my $xp_awarded = int $xp * $total_percent;

		#warn $xp_awarded;
				
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

# Check the effects at the end of the round, decrement the timer, and delete any that have expired
sub process_effects : Private {
	my ($self, $c) = @_;
	
	my @character_effects = $c->model('DBIC::Character_Effect')->search(
		{
			character_id => [ map { $_->id } $c->stash->{party}->characters ],
			'effect.combat' => 1,
		},
		{
			prefetch => 'effect',
		},
	);

	my @creature_effects = $c->model('DBIC::Creature_Effect')->search(
		{
			creature_id => [ map { $_->id } $c->stash->{creature_group}->creatures ],
			'effect.combat' => 1,
		},
		{
			prefetch => 'effect',
		},
	);
	
	foreach my $effect (@character_effects, @creature_effects) {
		$effect->effect->time_left($effect->effect->time_left-1);
		
		if ($effect->effect->time_left == 0) {
			$effect->effect->delete;
			$effect->delete;	
		}
		else {
			$effect->effect->update;
		}
	}	
}

1;
