package RPG::Combat::Battle;

use Moose::Role;

use List::Util qw(shuffle);
use Carp;
use Storable qw(freeze thaw);
use DateTime;
use Data::Dumper;
use Math::Round qw(round);

use RPG::Combat::ActionResult;
use RPG::Combat::MessageDisplayer;
use RPG::Combat::MagicalDamage;
use RPG::Combat::EffectResult;

use feature 'switch';

requires qw/process_effects opponents_of opponents check_for_flee finish opponent_of_by_id initiated_by is_online/;

has 'schema' => ( is => 'ro', isa => 'RPG::Schema', required => 1 );
has 'config' => ( is => 'ro', isa => 'HashRef',     required => 0 );
has 'log'    => ( is => 'ro', isa => 'Object',      required => 1 );

# Private
has 'session'           => ( is => 'ro', isa => 'HashRef',                 init_arg => undef, builder => '_build_session',           lazy => 1 );
has 'combat_log'        => ( is => 'ro', isa => 'RPG::Schema::Combat_Log', init_arg => undef, builder => '_build_combat_log',        lazy => 1 );
has 'combat_factors'    => ( is => 'rw', isa => 'HashRef',                 required => 0,     builder => '_build_combat_factors',    lazy => 1, );
has 'character_weapons' => ( is => 'ro', isa => 'HashRef',                 required => 0,     builder => '_build_character_weapons', lazy => 1, );
has 'combatants_by_id'  => ( is => 'ro', isa => 'HashRef',                 init_arg => undef, builder => '_build_combatants_by_id',  lazy => 1, );
has 'result' => ( is => 'ro', isa => 'HashRef', init_arg => undef, default => sub { {} } );

sub opponent_number_of_being {
	my $self  = shift;
	my $being = shift;

	return $self->opponent_number_of_group( $being->group );
}

sub opponent_number_of_group {
	my $self  = shift;
	my $group = shift;

	my ($opp1) = ( $self->opponents )[0];

	if ( $group->id == $opp1->id && $group->group_type eq $opp1->group_type ) {
		return 1;
	}
	else {
		return 2;
	}
}

sub opponents_of {
	my $self  = shift;
	my $being = shift;

	my @opponents = $self->opponents;
	
	if ($opponents[0]->has_being($being)) {
		return $opponents[1];
	}
	else {
		return $opponents[0];
	}
}

sub execute_round {
	my $self = shift;
	
	# Clear any messages from the last round
	$self->result->{messages} = undef;

	# Check for stalemates, fleeing or no one alive in one of the groups
	#  The latter should be caught from the end of the previous round, but we also check it here to be defensive
	my $dead_group = $self->check_for_end_of_combat;
	if ( $self->stalemate_check || $self->check_for_flee || $dead_group ) {

		# One opponent has fled, end of the battle
		$self->end_of_combat_cleanup;

		$self->result->{combat_complete} = 1;

		$self->combat_log->increment_rounds;

		$self->record_messages;

		return $self->result;
	}

	# Process magical effects
	$self->process_effects;

	if ($self->result->{combat_complete}) {	
		$self->combat_log->increment_rounds;

		$self->record_messages;
		
		return $self->result;
	}

	my @combatants = $self->combatants;

	# Get list of combatants, modified for changes in attack frequency, and randomised in order
	@combatants = $self->get_combatant_list(@combatants);

	my @combat_messages;

	foreach my $combatant (@combatants) {
		next if $combatant->is_dead;

		my $action_result;
		if ( $combatant->is_character ) {
			$action_result = $self->character_action($combatant);

			if ($action_result) {
				$self->session->{damage_done}{ $combatant->id } += $action_result->damage || 0;
			}
		}
		else {
			$action_result = $self->creature_action($combatant);
		}

		if ($action_result) {
			push @combat_messages, $action_result;

			$self->combat_log->record_damage( $self->opponent_number_of_being( $action_result->attacker ), $action_result->damage );

			if ( $action_result->defender_killed ) {
				$self->combat_log->record_death( $self->opponent_number_of_being( $action_result->defender ) );

				my $type = $action_result->defender->is_character ? 'character' : 'creature';
				push @{ $self->session->{killed}{$type} }, $action_result->defender->id;
			}

			if ( my $losers = $self->check_for_end_of_combat ) {
				last;
			}
		}
	}

	$self->combat_log->increment_rounds;

	push @{ $self->result->{messages} }, @combat_messages;

	$self->record_messages;

	return $self->result;
}

# If both sides are offline, check if any damage has been done in the last 10 rounds (on either side)
#  If no damage has been done, declare a 'stalemate'. This prevents battles lasting forever
sub stalemate_check {
	my $self = shift;

	return 0 if $self->is_online;

	return 0 if ! defined $self->combat_log->rounds || $self->combat_log->rounds == 0 || $self->combat_log->rounds % 10 != 0;

	if ( $self->session->{stalemate_check} != 0 ) {

		# Damage done, so no stalemate
		$self->session->{stalemate_check} = 0;
		return 0;
	}
	else {

		# It's a stalemate
		$self->result->{stalemate} = 1;
		return 1;
	}
}

sub check_for_end_of_combat {
	my $self = shift;

	foreach my $opponents ( $self->opponents ) {
		if ( $opponents->number_alive <= 0 ) {
			my $opp = 'opp' . ($self->opponent_number_of_group($opponents) == 1 ? 2 : 1);

			#$self->log->debug("Combat over, opp #$opp won"); 

			$self->combat_log->outcome( $opp . "_won" );
			$self->combat_log->encounter_ended( DateTime->now() );

			$self->result->{combat_complete} = 1;

			# TODO: should be in a role?
			if ( $opponents->group_type eq 'party' ) {
				$opponents->disband;
			}
			
			$self->result->{losers} = $opponents;
			$self->finish($opponents);
			$self->end_of_combat_cleanup;

			return $opponents;
		}
	}
}

# TODO: needs a better name
sub _process_effects {
	my $self    = shift;
	my @effects = @_;

	foreach my $effect (@effects) {
		my $being;
		if ( $effect->can('character_id') ) {
			$being = $self->combatants_by_id->{character}{ $effect->character_id };
		}
		else {
			$being = $self->combatants_by_id->{creature}{ $effect->creature_id };
		}

		if ( !$being->is_dead && $effect->effect->modified_stat eq 'poison' ) {
			my $damage = Games::Dice::Advanced->roll( '1d' . $effect->effect->modifier );
			
			$being->hit($damage, $self->opponents_of($being));

			my $result = RPG::Combat::EffectResult->new(
				defender => $being,
				damage   => $damage,
				effect   => 'poison',
			);

			push @{ $self->result->{messages} }, $result;
			
			if ($self->check_for_end_of_combat) {
				return;
			}
		}

		$effect->effect->time_left( $effect->effect->time_left - 1 );

		if ( $effect->effect->time_left <= 0 ) {
			$effect->effect->delete;
			$effect->delete;

			# Reload the combatant who has this effect, to make sure it's now gone
			$being->discard_changes;

		}
		else {
			$effect->effect->update;
		}
	}
}

# Record combat messages in the DB
sub record_messages {
	my $self = shift;

	my @opponents = $self->opponents;
	my %display_messages;

	foreach my $opp_number ( 1 .. 2 ) {
		next if $opponents[ $opp_number - 1 ]->group_type eq 'creature_group';

		my @messages = RPG::Combat::MessageDisplayer->display(
			config   => $self->config,
			group    => $opponents[ $opp_number - 1 ],
			opponent => $opponents[ $opp_number == 1 ? 1 : 0 ],
			result   => $self->result
		);

		$self->schema->resultset('Combat_Log_Messages')->create(
			{
				combat_log_id   => $self->combat_log->id,
				round           => $self->combat_log->rounds,
				opponent_number => $opp_number,
				message         => join "", @messages,
			},
		);

		$display_messages{$opp_number} = \@messages;
	}

	$self->result->{display_messages} = \%display_messages;
}

sub get_combatant_list {
	my $self       = shift;
	my @combatants = @_;

	my @sorted_combatants;

	foreach my $combatant (@combatants) {
		my @attack_history;

		my $type = $combatant->is_character ? 'character' : 'creature';

		@attack_history = @{ $self->session->{attack_history}{$type}{ $combatant->id } }
			if $self->session->{attack_history}{$type}{ $combatant->id };

		my $number_of_attacks = $combatant->number_of_attacks(@attack_history);

		push @attack_history, $number_of_attacks;

		$self->session->{attack_history}{$type}{ $combatant->id } = \@attack_history;

		for ( 1 .. $number_of_attacks ) {
			push @sorted_combatants, $combatant;
		}
	}

	@sorted_combatants = shuffle @sorted_combatants;

	return @sorted_combatants;
}

sub character_action {
	my ( $self, $character ) = @_;

	my $opp_group = $self->opponents_of($character);

	my %opponents = map { $_->id => $_ } $opp_group->members;

	# Check if spell casters should do an auto cast
	my $autocast = $character->last_combat_param1 eq 'autocast' ? 1 : 0;
	my ($spell, $target) = $self->check_for_auto_cast($character);
	if ($spell) {
        $character->last_combat_action('Cast');
		$character->last_combat_param1( $spell->id );
		$character->last_combat_param2( $target->id );
	}
	elsif ($autocast) {
	    # They have auto-cast set, but didn't cast a spell. Set them to attack instead
	    $character->last_combat_action('Attack');
	    $character->last_combat_param1(undef);
	    $character->last_combat_param2(undef);
	}
	
	my $result;	    

	if ( $character->last_combat_action eq 'Attack' ) {

		my ( $opponent, $damage );

		# If they've selected a target, or have one saved from last round make sure it's still alive
		my $targetted_opponent_id = $character->last_combat_param1 || $self->session->{previous_opponents}{$character->id};

		if ( $targetted_opponent_id && $opponents{$targetted_opponent_id} && !$opponents{$targetted_opponent_id}->is_dead ) {
			$opponent = $opponents{$targetted_opponent_id};
		}

		# If we don't have a target, choose one randomly
		unless ($opponent) {
			for my $id ( shuffle keys %opponents ) {
				unless ( $opponents{$id}->is_dead ) {
					$opponent = $opponents{$id};
					last;
				}
			}

			unless ($opponent) {

				# No living opponent found, something weird has happened
				confess "Couldn't find an opponent to attack!\n";
			}
		}
		
		# Save opponent in session for next round so they keep attacking the same guy
		#  (Unless they die, or they target someone else)
		$self->session->{previous_opponents}{$character->id} = $opponent->id;

		$damage = $self->attack( $character, $opponent );

		# Store damage done for XP purposes
		my %action_params;
		if ( ref $damage ) {
			%action_params = %$damage;
		}
		else {
			$action_params{damage} = $damage;
		}

		$result = RPG::Combat::ActionResult->new(
			attacker => $character,
			defender => $opponent,
			%action_params,
		);

		if ( my $type = $self->character_weapons->{ $character->id }{magical_damage_type} ) {
			$self->apply_magical_damage(
				$character, $opponent, $result, $type,
				$self->character_weapons->{ $character->id }{magical_damage_level}
			);
		}
	}
	elsif ( $character->last_combat_action eq 'Cast' || $character->last_combat_action eq 'Use' ) {
		my $obj;
		my $target_type;
		if ( $character->last_combat_action eq 'Cast' ) {
			$obj = $self->schema->resultset('Spell')->find( $character->last_combat_param1 );

			$target_type = $obj->target;
		}
		else {
			$obj = $self->schema->resultset('Item_Enchantments')->find( $character->last_combat_param1 );

			confess "Attempt to use item that belongs to another character"
				unless $obj->item->character_id == $character->id;

			$target_type = $obj->spell->target;
		}

		my $target;
		if ( $target_type eq 'character' ) {
			$target = $self->combatants_by_id->{'character'}{ $character->last_combat_param2 };
		}
		else {
			$target = $self->opponent_of_by_id( $character, $character->last_combat_param2 );
		}

		if ( $character->last_combat_action eq 'Cast' ) {
			$result = $obj->cast( $character, $target );
		}
		else {
			$result = $obj->use($target);
		}

		# Since effects could have changed an af or df, we re-calculate the target's factors
		$self->refresh_factor_cache( $target_type, $character->last_combat_param2 );
		
		# Make sure any healing/damage etc. is taken into account
		$target->discard_changes;

        $character->last_combat_action('Attack');

        $self->session->{spells_cast}{$character->id}++;
		$self->combat_log->spells_cast( $self->combat_log->spells_cast + 1 );
	}
	
	# If they were auto-casting, set them back to auto-cast for next round
	if ($autocast) {
        $character->last_combat_action('Cast');   
	    $character->last_combat_param1('autocast');
	    $character->last_combat_param2(undef);	   
	}
    $character->update;
    
    return $result;
	
}

sub apply_magical_damage {
	my $self          = shift;
	my $character     = shift;
	my $opponent      = shift;
	my $action_result = shift;
	my $type          = shift;
	my $level         = shift;

	return if $action_result->damage == 0 || $opponent->is_dead;

	my $package = 'RPG::Combat::MagicalDamage::' . $type;

	my $magical_damage_result = $package->apply(
		character      => $character,
		opponent       => $opponent,
		opponent_group => $self->opponents_of($character),
		level          => $level,
		schema         => $self->schema,
	);

	$action_result->magical_damage($magical_damage_result);
}

sub check_for_auto_cast {
	my $self      = shift;
	my $caster    = shift;
	
	return unless $caster->is_spell_caster;
	
	if ( my $spell = $caster->check_for_auto_cast ) {
        my $target;

		# Randomly select a target
		given ( $spell->target ) {
			when ('creature') {
            	my $opp_group = $self->opponents_of($caster);
            	my %opponents = map { $_->id => $_ } $opp_group->members;

				for my $id ( shuffle keys %opponents ) {
					unless ( $opponents{$id}->is_dead ) {
						$target = $opponents{$id};
						last;
					}
				}
			}
			when ('character') {
				$target = ( shuffle grep { !$_->is_dead } $caster->group->members )[0];
			}
			when ('party') {
			    my $opp_num = $self->opponent_number_of_being($caster);
                $target = ( $self->opponents )[$opp_num-1];			
			}
			default {
				# Currently only combat spells with creature/character target are implemented
				confess "Auto-cast can't handle spell target: $_";
			}
		}
		
		return ($spell, $target);
	}
}

sub creature_action {
	my ( $self, $creature ) = @_;

	my $party = $self->opponents_of($creature);
	
	my ($spell, $target) = $self->check_for_auto_cast($creature);
	if ($spell) {
	    return $spell->creature_cast($creature, $target);
	}

	my @characters = sort { ($a->party_order || 0) <=> ($b->party_order || 0) } $party->members;
	@characters = grep { !$_->is_dead } @characters;    # Get rid of corpses

	# Figure out whether creature will target front or back rank
	my $rank_pos = $party->rank_separator_position;

	$rank_pos = scalar @characters if $rank_pos > scalar @characters;

	unless ( $rank_pos == scalar @characters ) {
		my $rank_roll = Games::Dice::Advanced->roll('1d100');
		if ( $rank_roll <= $self->config->{front_rank_attack_chance} ) {

			# Remove everything but front rank
			splice @characters, $rank_pos;
		}
		else {

			# Remove everything but back rank
			splice @characters, 0, $rank_pos;
		}
	}

	# Go back to original list if there's nothing in characters (i.e. there are only dead (or no) chars in this rank)
	@characters = $party->members unless scalar @characters > 0;

	my $character;
	foreach my $char_to_check ( shuffle @characters ) {
		unless ( $char_to_check->is_dead ) {
			$character = $char_to_check;
			last;
		}
	}

	unless ($character) {
		confess "Couldn't find a character to attack!\n";
	}

	# Count number of times attacked for XP purposes
	$self->session->{attack_count}{ $character->id }++;

	my $damage = $self->attack( $creature, $character );
	
	my $action_result = RPG::Combat::ActionResult->new(
		attacker => $creature,
		defender => $character,
		damage   => $damage,
	);
	
	if ($creature->type->special_damage) {
		$self->apply_magical_damage(
			$creature, $character, $action_result, $creature->type->special_damage, int $creature->type->level / 3
		);
	}

	return $action_result;
}

sub attack {
	my $self = shift;
	my ( $attacker, $defender ) = @_;

	my $attacker_type = $attacker->is_character ? 'character' : 'creature';

	$self->log->debug("About to check attack");

	if ( $attacker_type eq 'character' ) {
		my $attack_error = $self->check_character_attack($attacker);

		$self->log->debug( "Got attack error: " . Dumper $attack_error);
		return $attack_error if $attack_error;
	}

	my $defending = 0;
	if ( $defender->is_character && $defender->last_combat_action eq 'Defend' ) {
		$defending = 1;
	}

	$self->log->debug("About to execute defence");

	if ( my $defence_message = $defender->execute_defence ) {
		if ( $defence_message->{armour_broken} ) {

			# Armour has broken, clear out this character's factor cache
			$self->refresh_factor_cache( 'character', $attacker->id );
		}
	}

	my $a_roll = Games::Dice::Advanced->roll( '1d' . $self->config->{attack_dice_roll} );
	my $d_roll = Games::Dice::Advanced->roll( '1d' . $self->config->{defence_dice_roll} );

	my $defence_bonus = $defending ? $self->config->{defend_bonus} : 0;

	my $af = $self->combat_factors->{ $attacker->is_character ? 'character' : 'creature' }{ $attacker->id }{af};

	if ( $attacker->is_character && !$defender->is_character ) {
		if ( my $bonuses = $self->character_weapons->{ $attacker->id }{creature_bonus} ) {
			$af += $bonuses->{ $defender->type->category->id } || 0;
		}
	}

	my $df = $self->combat_factors->{ $defender->is_character ? 'character' : 'creature' }{ $defender->id }{df};

	my $aq = $af - $a_roll;
	my $dq = $df + $defence_bonus - $d_roll;

	$self->log->debug( "Executing attack. Attacker: " . $attacker->name . ", Defender: " . $defender->name );

	$self->log->debug("Attack:  Factor: $af Roll: $a_roll  Quotient: $aq");
	$self->log->debug("Defence: Factor: $df Roll: $d_roll  Quotient: $dq Bonus: $defence_bonus ");

	my $damage = 0;

	if ( $aq > $dq ) {

		# Attack hits
		my $dam_max = $self->combat_factors->{ $attacker->is_character ? 'character' : 'creature' }{ $attacker->id }{dam};
		$damage = Games::Dice::Advanced->roll( '1d' . $dam_max )
			unless $dam_max <= 0;

		$defender->hit($damage, $attacker);

		$self->session->{stalemate_check} += $damage;

		if ( $defender->is_dead ) {

			# TODO: move to schema class?
			if ( $defender->is_character ) {
				my $attacker_type = $attacker->is_character ? $attacker->class->class_name : $attacker->type->creature_type;

				$self->schema->resultset('Character_History')->create(
					{
						character_id => $defender->id,
						day_id       => $self->schema->resultset('Day')->find_today->id,
						event        => $defender->character_name . " was slain by a " . $attacker_type,
					},
				);
			}
		}

		$self->log->debug("Damage: $damage");
	}

	return $damage;
}

# TODO: could be moved into Schema class (and have equivilent for any being, like execute_defence)
#  needs a bit of refactoring to make sure weapons, etc. are cached though.
sub check_character_attack {
	my ( $self, $attacker ) = @_;

	return unless defined $self->character_weapons->{ $attacker->id }{id};

	unless ( $self->character_weapons->{ $attacker->id }{indestructible} ) {
		my $weapon_durability = $self->character_weapons->{ $attacker->id }{durability} || 0;

		return { weapon_broken => 1 }
			if $weapon_durability == 0
				&& !$self->character_weapons->{ $attacker->id }{indestructible};

		my $weapon_damage_roll = Games::Dice::Advanced->roll('1d3');

		if ( $weapon_damage_roll == 1 ) {

			$self->log->debug('Reducing durability of weapon');
			$weapon_durability--;

			my $var = $self->schema->resultset('Item_Variable')->find(
				{
					item_id                                 => $self->character_weapons->{ $attacker->id }{id},
					'item_variable_name.item_variable_name' => 'Durability',
				},
				{ join => 'item_variable_name', }
			);

			if ($var) {
				$var->update( { item_variable_value => $weapon_durability, } );
				$self->character_weapons->{ $attacker->id }{durability} = $weapon_durability;
			}
		}

		if ( $weapon_durability <= 0 ) {

			# TODO: need to refresh party list
			#push @{ $c->stash->{refresh_panels} }, 'party';
			return { weapon_broken => 1 };
		}
	}

	if ( ref $self->character_weapons->{ $attacker->id }{ammunition} eq 'ARRAY' ) {

		$self->log->debug('Checking for ammo');
		my $ammo_found = 0;
		foreach my $ammo ( @{ $self->character_weapons->{ $attacker->id }{ammunition} } ) {
			next unless $ammo;
			
			$ammo_found = 1 if $ammo->{quantity} > 0;
						
			$ammo->{quantity}--;
			if ( $ammo->{quantity} <= 0 ) {
				# Ammo used up, so delete it
				$self->schema->resultset('Items')->find( { item_id => $ammo->{id}, }, )->delete;
				$ammo = undef;
			}
			else {
				# Update with new ammo amount
				$self->schema->resultset('Item_Variable')->find(
					{
						item_id                                 => $ammo->{id},
						'item_variable_name.item_variable_name' => 'Quantity',
					},
					{ join => 'item_variable_name', }
				)->update( { item_variable_value => $ammo->{quantity}, } );
			}

			last if $ammo_found;
		}

		if ( !$ammo_found ) {
			return { no_ammo => 1 };
		}
	}

	return;
}

# Party (or garrison) attempts to flee
# Param passed is party's opponent number
sub party_flee {
	my $self       = shift;
	my $opp_number = shift;

	my @opponents = $self->opponents;

	my $party = $opponents[ $opp_number - 1 ];
	my $opponent = $opponents[ $opp_number == 1 ? 1 : 0 ];

	my $flee_attempts_column = 'opponent_' . $opp_number . '_flee_attempts';
	$self->combat_log->set_column( $flee_attempts_column, ( $self->combat_log->get_column($flee_attempts_column) || 0 ) + 1 );

	my $flee_successful = $self->roll_flee_attempt( $party, $opponent, $opp_number );
	if ($flee_successful) {
		my $sector = $self->get_sector_to_flee_to($party);

		$party->move_to($sector);
		$party->update;

		$self->combat_log->outcome( 'opp' . $opp_number . '_fled' );
		$self->combat_log->encounter_ended( DateTime->now() );

		return 1;
	}
}

sub roll_flee_attempt {
	my $self             = shift;
	my $fleers           = shift;
	my $opponents        = shift;
	my $fleer_opp_number = shift;

	my $level_difference = $opponents->level - $fleers->level;
	my $flee_chance =
		$self->config->{base_flee_chance} + ( $self->config->{flee_chance_level_modifier} * ( $level_difference > 0 ? $level_difference : 0 ) );

	if ( $fleers->level == 1 ) {

		# Bonus chance for being low level
		$flee_chance += $self->config->{flee_chance_low_level_bonus};
	}

	my $flee_attempts_column = 'opponent_' . $fleer_opp_number . '_flee_attempts';
	$flee_chance += ( $self->config->{flee_chance_attempt_modifier} * ( $self->combat_log->get_column($flee_attempts_column) || 0 ) );

	my $rand = Games::Dice::Advanced->roll("1d100");

	$self->log->debug("Flee roll: $rand");
	$self->log->debug( "Flee chance: " . $flee_chance );

	return $rand <= $flee_chance ? 1 : 0;
}

sub end_of_combat_cleanup {
	my $self = shift;
	
	foreach my $opponent ($self->opponents) {
		if ($opponent->can('end_combat') && $opponent->in_storage) {
			$opponent->end_combat;	
		}
	}

	foreach my $combatant ( $self->combatants ) {
		next unless $combatant->is_character;

		# Remove character effects from this combat
		foreach my $effect ( $combatant->character_effects ) {
			$effect->delete if $effect->effect->combat;
		}

		# Remove last_combat_actions that can't be carried between combats
		if ( $combatant->last_combat_action eq 'Cast' || $combatant->last_combat_action eq 'Use' ) {
			$combatant->last_combat_action('Attack');			
		}
		$combatant->last_combat_param1(undef);
		$combatant->last_combat_param2(undef);
		$combatant->update;
	}
}

sub distribute_xp {
	my ( $self, $xp, $char_ids ) = @_;

	my %awarded_xp;
	$xp //= 0;    # Everyone gets 10% to start with
	my $min_xp = int $xp * 0.1;
	@awarded_xp{@$char_ids} = ($min_xp) x scalar @$char_ids;
	$xp -= $min_xp * scalar @$char_ids;

	# Work out total damage, total attacks made and total spells cast
	my ( $total_damage, $total_attacks, $total_spells_cast ) = ( 0, 0, 0 );
	map { $total_damage  += $_ } values %{ $self->session->{damage_done} };
	map { $total_attacks += $_ } values %{ $self->session->{attack_count} };
	map { $total_spells_cast += $_ } values %{ $self->session->{spells_cast} };

	my $total_awarded = 0;
	
	# Weighting depend on whether any spells were cast
	my ($damage_weight, $attack_weight, $spell_weight);
	if ($total_spells_cast <= 0) {
	   $damage_weight = 0.6;
	   $attack_weight = 0.4;
	   $spell_weight = 0;   
	}
	else {
	   $damage_weight = 0.5;
	   $attack_weight = 0.25;
	   $spell_weight = 0.25;
	}

	# Assign each character XP points, up to a max of 35% of the pool
	foreach my $char_id (@$char_ids) {
		my ( $damage_percent, $attacked_percent, $spells_percent ) = ( 0, 0, 0 );

		$damage_percent = ( ( $self->session->{damage_done}{$char_id} || 0 ) / $total_damage ) * $damage_weight
			if $total_damage > 0;
		$attacked_percent = ( ( $self->session->{attack_count}{$char_id} || 0 ) / $total_attacks ) * $attack_weight
			if $total_attacks > 0;
		$spells_percent = ( ( $self->session->{spells_cast}{$char_id} || 0 ) / $total_spells_cast ) * $spell_weight
			if $total_spells_cast > 0;

		my $total_percent = $damage_percent + $attacked_percent + $spells_percent;
		$total_percent = 0.35 if $total_percent > 0.35;

		my $xp_awarded = round $xp * $total_percent;

		$awarded_xp{$char_id} += $xp_awarded;
		$total_awarded += $xp_awarded;
	}

	# Figure out how much is left, if any
	$xp -= $total_awarded;

	# If there's any XP left, divide it up amongst the party. We round down, so some could be lost
	if ( $xp > 0 ) {
		my $spare_xp = int( $xp / scalar @$char_ids );
		map { $awarded_xp{$_} += $spare_xp } keys %awarded_xp;
	}

	return \%awarded_xp;
}

sub _build_session {
	my $self = shift;

	return {} unless $self->combat_log->session;

	return thaw $self->combat_log->session;
}

sub _build_combat_log {
	my $self = shift;

	my ( $opp1, $opp2 ) = $self->opponents;

	my $combat_log = $self->schema->resultset('Combat_Log')->find(
		{
			opponent_1_id   => $opp1->id,
			opponent_1_type => $opp1->group_type,
			opponent_2_id   => $opp2->id,
			opponent_2_type => $opp2->group_type,
			encounter_ended => undef,
		},
	);

	if ( !$combat_log ) {
		$combat_log = $self->schema->resultset('Combat_Log')->create(
			{
				opponent_1_id       => $opp1->id,
				opponent_1_type     => $opp1->group_type,
				opponent_2_id       => $opp2->id,
				opponent_2_type     => $opp2->group_type,
				encounter_started   => DateTime->now(),
				combat_initiated_by => $self->initiated_by,
				opponent_1_level    => $opp1->level,
				opponent_2_level    => $opp2->level,
				game_day            => $self->schema->resultset('Day')->find_today->id,
				spells_cast         => 0,

				$self->combat_log_location_attribute => $self->location->id,
			},
		);
	}

	return $combat_log;
}

# Refresh a combatant's details in the factor cache
sub refresh_factor_cache {
	my ( $self, $combatant_type, $combatant_id_to_refresh ) = @_;

    delete $self->session->{combat_factors}{$combatant_type}{$combatant_id_to_refresh};

	$self->combat_factors( $self->_build_combat_factors($combatant_type, $combatant_id_to_refresh) );
}

sub _build_combat_factors {
	my $self = shift;
	my $refresh_type = shift;
	my $id = shift;

	my %combat_factors;

	%combat_factors = %{ $self->session->{combat_factors} } if defined $self->session->{combat_factors};

	foreach my $combatant ( $self->combatants ) {
		next if $combatant->is_dead;
		
		my $type = $combatant->is_character ? 'character' : 'creature';

		if (defined $id) {
            next unless $id == $combatant->id && $type eq $refresh_type; 
		}

		next if defined $combat_factors{$type}{ $combatant->id };

		$combat_factors{$type}{ $combatant->id }{af}  = $combatant->attack_factor;
		$combat_factors{$type}{ $combatant->id }{df}  = $combatant->defence_factor;
		$combat_factors{$type}{ $combatant->id }{dam} = $combatant->damage;
	}

	$self->session->{combat_factors} = \%combat_factors;

	return \%combat_factors;
}

sub _build_character_weapons {
	my $self = shift;

	my %character_weapons;

	return $self->session->{character_weapons} if defined $self->session->{character_weapons};

	foreach my $combatant ( $self->combatants ) {
		next unless $combatant->is_character;

		my ($weapon) = $combatant->get_equipped_item('Weapon');

		if ($weapon) {
			$character_weapons{ $combatant->id }{id}                   = $weapon->id;
			$character_weapons{ $combatant->id }{durability}           = $weapon->variable('Durability');
			$character_weapons{ $combatant->id }{indestructible}       = $weapon->variable('Indestructible');
			$character_weapons{ $combatant->id }{ammunition}           = $combatant->ammunition_for_item($weapon);
			$character_weapons{ $combatant->id }{magical_damage_type}  = $weapon->variable('Magical Damage Type');
			$character_weapons{ $combatant->id }{magical_damage_level} = $weapon->variable('Magical Damage Level');

			my @enchantments = $weapon->item_enchantments;
			my %creature_bonus;
			foreach my $enchantment (@enchantments) {
				if ( $enchantment->enchantment->enchantment_name eq 'bonus_against_creature_category' ) {
					$creature_bonus{ $enchantment->variable('Creature Category') } = $enchantment->variable('Bonus');
				}
			}

			$character_weapons{ $combatant->id }{creature_bonus} = \%creature_bonus;

		}
		else {
			$character_weapons{ $combatant->id }{durability} = 1;
		}
	}

	$self->session->{character_weapons} = \%character_weapons;

	return \%character_weapons;
}

sub _build_combatants_by_id {
	my $self = shift;

	my %combatants_by_id;

	foreach my $combatant ( $self->combatants ) {
		my $type = $combatant->is_character ? 'character' : 'creature';
		$combatants_by_id{$type}{ $combatant->id } = $combatant;
	}

	return \%combatants_by_id;
}

sub DEMOLISH {
	my $self = shift;

	if ( $self->session ) {
		my $session = freeze $self->session;
		$self->combat_log->session($session);
	}

	$self->combat_log->update;
}

1;
