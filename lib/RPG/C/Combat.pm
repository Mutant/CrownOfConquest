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
		$c->forward('/panel/refresh', ['messages', 'party']);
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
				creatures_initiated => 0, #TODO: fixme! $params->{creatures_initiated},
				combat_messages => $c->stash->{combat_messages},
				combat_complete => $c->stash->{combat_complete},
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
	
	my @action_params = grep { $_ } $c->req->param('action_param'); 
	
	$c->session->{combat_action_param}{$c->req->param('character_id')} = 
		scalar @action_params > 1 ? \@action_params : $action_params[0];
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
	
	$c->stash->{characters} = { map { $_->id => $_ } @characters };
	$c->stash->{creatures}  = { map { $_->id => $_ } @creatures  };
	
	$c->forward('process_effects');
	
	# Find out if any chars are allowed a second attack
	my $allowed_second_attack = $c->forward('characters_allowed_second_attack', \@characters);
	push @characters, @$allowed_second_attack; 
	
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
			if (ref $action_result) {
				my ($target, $damage) = @$action_result;
				
				push @combat_messages, {
					attacker => $combatant, 
					defender => $target, 
					damage => $damage || 0,
				};
			}
			else {
				push @combat_messages, $action_result;
			}
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
    
	$c->forward('/panel/refresh', ['messages', 'party']);
}

sub character_action : Private {
	my ($self, $c, $character, $creature_group) = @_;	
	
	my ($creature, $damage);
	
	if ($character->last_combat_action eq 'Attack') {
		# If they've selected a target, make sure it's still alive
		my $targetted_creature = $c->session->{combat_action_param}{$character->id};
		warn Dumper $targetted_creature;
		if ($targetted_creature && $c->stash->{creatures}{$targetted_creature} && ! $c->stash->{creatures}{$targetted_creature}->is_dead) {
			$creature = $c->stash->{creatures}{$targetted_creature};
		}
		
		# If we don't have a target, choose one randomly
		unless ($creature) {
			do {
				my @ids = shuffle keys %{$c->stash->{creatures}};
				$creature = $c->stash->{creatures}{$ids[0]};
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
		
		return $message;
	}
}

sub creature_action : Private {
	my ($self, $c, $creature, $party) = @_;
		
	my @characters = sort { $a->party_order <=> $b->party_order } $party->characters;
	
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

sub characters_allowed_second_attack : Private {
	my ($self, $c, @characters) = @_;
	
	my @allowed_second_attack;
	foreach my $character (@characters) {
		# TODO: currently hardcoded class name and item category, but could be in the DB
		next unless $character->class->class_name eq 'Archer';
		
		my @weapons = $character->get_equipped_item('Weapon');
		
		my $ranged_weapons = grep { $_->item_type->category->item_category eq 'Ranged Weapon' } @weapons;
		
		$c->session->{rounds_since_last_double_attack}{$character->id}++;
		
		# TODO: config or add to DB number of rounds for 2nd attack
		if ($ranged_weapons >= 0 && $c->session->{rounds_since_last_double_attack}{$character->id} == 2) {
			$c->session->{rounds_since_last_double_attack}{$character->id} = 0;
			push @allowed_second_attack, $character;			
		}
	}
	
	return \@allowed_second_attack;		
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

		my %x_y_range = $c->model('Land')->get_x_y_range();

		# Find sector to flee to
		my @adjacent_sectors = RPG::Map->get_adjacent_sectors(
			$party_location->x,
			$party_location->y,
			$x_y_range{min_x},
			$x_y_range{min_y},
			$x_y_range{max_x},
			$x_y_range{max_y},
		);
		@adjacent_sectors = shuffle @adjacent_sectors;
		
		my ($new_x, $new_y) = @{shift @adjacent_sectors};
		
		$c->log->debug("Fleeing to: $new_x, $new_y");
		
		my $land = $c->model('Land')->find({
			x => $new_x,
			y => $new_y,
		});
		
		$c->error("Couldn't find sector: $new_x, $new_y"), return unless $land;
		
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
    	
    	$c->forward('/panel/refresh', ['messages', 'map', 'party', 'party_status']);
	}
	else {
		push @{ $c->stash->{combat_messages} }, 'You were unable to flee.';
		$c->forward('/combat/fight');
	}
}

sub finish : Private {
	my ($self, $c) = @_;	
	
	my @creatures = $c->stash->{creature_group}->creatures;
	
	undef $c->session->{combat_action_param};
	undef $c->session->{rounds_since_last_double_attack};
	
	my $xp;
	
	my $level_aggr = 0;
	foreach my $creature (@creatures) {
		# Generate random modifier between 0.6 and 1.5
		my $rand = (Games::Dice::Advanced->roll('1d10') / 10) + 0.5;
		$xp += int ($creature->type->level * $rand * RPG->config->{xp_multiplier});
		
		$level_aggr += $creature->type->level; 
	}

	my $avg_creature_level = $level_aggr / scalar @creatures;
	
	my @characters = $c->stash->{party}->characters;
	
	my $awarded_xp = $c->forward('/combat/distribute_xp', [ $xp, [map { $_->is_dead ? () : $_->id } @characters] ] );
	
	foreach my $character (@characters) {
		next if $character->is_dead;
		
		# TODO template these combat messages? (yes)
		push @{$c->stash->{combat_messages}}, $character->character_name . " gained " . $awarded_xp->{$character->id} . " xp.";
		
		my $level_up_details = $character->xp($character->xp + $awarded_xp->{$character->id});
		
		if (ref $level_up_details eq 'HASH' && $level_up_details->{hit_points}) {
			push @{$c->stash->{combat_messages}}, $character->character_name . " went up a level! (Now level " . $character->level . ")";
			push @{$c->stash->{combat_messages}}, $character->character_name . " gained " . $level_up_details->{hit_points} . " hit points.";
			push @{$c->stash->{combat_messages}}, $character->character_name . " gained " . $level_up_details->{magic_points} . " magic points."
				if $level_up_details->{magic_points};
			push @{$c->stash->{combat_messages}}, $character->character_name . " gained " . $level_up_details->{prayer_points} . " prayer points."
				if $level_up_details->{prayer_points};
			push @{$c->stash->{combat_messages}}, $character->character_name . " gained " . $level_up_details->{stat_points} . " stat points."
				if $level_up_details->{stat_points};
		}
		
		$character->update;
	}
	my $gold = scalar(@creatures) * $avg_creature_level * Games::Dice::Advanced->roll('1d10');
	
	push @{$c->stash->{combat_messages}}, "You find $gold gold";
	
	$c->forward('check_for_item_found', [\@characters, $avg_creature_level]);

	$c->stash->{party}->in_combat_with(undef);
	$c->stash->{party}->gold($c->stash->{party}->gold + $gold);
	$c->stash->{party}->update;	
	
	$c->stash->{creature_group}->delete;
	
	$c->stash->{party_location}->creature_threat($c->stash->{party_location}->creature_threat - 5);
	$c->stash->{party_location}->update;
	
	push @{ $c->stash->{refresh_panels} }, 'party_status';
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

# Check the effects at the end of the round, decrement the timer, and delete any that have expired
sub process_effects : Private {
	my ($self, $c) = @_;
	
	my @effects = $c->model('DBIC::Character_Effect')->search(
		{
			character_id => [keys %{$c->stash->{characters}}],
			'effect.combat' => 1,
		},
		{
			prefetch => 'effect',
		},
	);
	
	foreach my $effect (@effects) {
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
