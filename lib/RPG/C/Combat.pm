package RPG::C::Combat;

use strict;
use warnings;
use base 'Catalyst::Controller';

use feature 'switch';

use Data::Dumper;
use Carp;

use RPG::Combat::CreatureWildernessBattle;

use Games::Dice::Advanced;
use List::Util qw(shuffle);
use DateTime;
use JSON;

# Check to see if creatures attack party (if there are any in their current sector)
sub check_for_attack : Local {
	my ( $self, $c, $new_land ) = @_;

	# See if party is in same location as a creature
	my $creature_group = $new_land->available_creature_group;

	# If there are creatures here, check to see if we go straight into combat
	if ( $creature_group && $creature_group->number_alive > 0 ) {
		$c->stash->{creature_group} = $creature_group;

		if ( $creature_group->initiate_combat( $c->stash->{party} ) ) {
			$c->stash->{party}->initiate_combat( $creature_group );
			$c->stash->{creatures_initiated} = 1;

			return $creature_group;
		}
	}
}

sub party_attacks : Local {
	my ( $self, $c ) = @_;

	my $creature_group = $c->stash->{party_location}->available_creature_group;

	push @{ $c->stash->{refresh_panels} }, 'map';

	$c->forward( 'execute_attack', [$creature_group] );

}

sub execute_attack : Private {
	my ( $self, $c, $creature_group ) = @_;

	if ($creature_group) {
		$c->stash->{creature_group} = $creature_group;

		$c->stash->{party}->initiate_combat( $creature_group );

		$c->forward( '/panel/refresh', [ 'messages', 'party' ] );
	}
	else {
		$c->stash->{messages} = "The creatures have moved, or have been attacked by someone else.";
		$c->forward( '/panel/refresh', ['messages'] );
	}

}

sub switch : Private {
	my ( $self, $c ) = @_;
	
	my $party = $c->stash->{party};
	
	return unless $party->in_combat_with;
	
	given ($party->combat_type) {
		when ('creature_group') {
			return $c->forward('/combat/main');
		}
		when ('garrison') {
			return $c->forward('/garrison/combat/main');
		}
	}
}

sub main : Local {
	my ( $self, $c ) = @_;

	my $creature_group = $c->stash->{creature_group};
	if ( !$c->stash->{combat_complete} && !$creature_group ) {
		$creature_group = $c->model('DBIC::CreatureGroup')->find(
			{
				creature_group_id => $c->stash->{party}->in_combat_with,
			},
			{
				prefetch => { 'creatures' => 'type' },
			},
		);
	}

	my $orb;
	if ( $c->stash->{creatures_initiated} && !$c->stash->{party}->dungeon_grid_id ) {
		$orb = $c->stash->{party_location}->orb;
	}

	my $creature_group_display;
	if ($creature_group) {
		$creature_group_display = $c->forward( '/combat/display_cg', [ $creature_group, $c->stash->{creatures_initiated} ] );
	}
	
	return $c->forward(
		'RPG::V::TT',
		[
			{
				template => 'combat/main.html',
				params   => {
					creature_group_display => $creature_group_display,
					creature_group         => $creature_group,
					creatures_initiated    => $c->stash->{creatures_initiated},
					combat_messages        => $c->stash->{combat_messages},
					combat_complete        => $c->stash->{combat_complete},
					party_dead             => $c->stash->{party}->defunct ? 1 : 0,
					orb                    => $orb,
					in_dungeon             => $c->stash->{party}->dungeon_grid_id ? 1 : 0,
				},
				return_output => 1,
			}
		]
	);
}

sub display_cg : Private {
	my ( $self, $c, $creature_group, $display_factor_comparison ) = @_;

	return unless $creature_group;

	my $factor_comparison;
	
	$c->stats->profile('Beginning factor comaprison');

	if ($display_factor_comparison) {

		# Check for a watcher effect
		my @effects = $c->stash->{party}->party_effects;
		
		$c->stats->profile('Got party effects');

		my $has_watcher = 0;
		foreach my $effect (@effects) {
			if ( $effect->effect && $effect->effect->effect_name eq 'Watcher' && $effect->effect->time_left > 0 ) {
				$has_watcher = 1;
				last;
			}
		}
		
		$c->stats->profile('Got watcher boolean');

		if ($has_watcher) {
			$c->log->debug('About to compare cg to party');
			$factor_comparison = $creature_group->compare_to_party( $c->stash->{party} );
			$c->log->debug('Done comparing cg to party');
		}
		
		$c->stats->profile('Compared to party');
	}
	
	$c->stats->profile('Completed factor comaprison');

	# Load effects, to make sure they're current (i.e. include current round)
	my @creature_effects = $c->model('DBIC::Creature_Effect')->search(
		{
			creature_id     => [ map { $_->id } $creature_group->creatures ],
			'effect.combat' => 1,
		},
		{ prefetch => 'effect', },
	);

	my %creature_effects_by_id;
	foreach my $effect (@creature_effects) {
		push @{ $creature_effects_by_id{ $effect->creature_id } }, $effect;
	}
	
	$c->stats->profile('Got creature effects');

	return $c->forward(
		'RPG::V::TT',
		[
			{
				template => 'combat/creature_group.html',
				params   => {
					creature_group         => $creature_group,
					factor_comparison      => $factor_comparison,
					creature_effects_by_id => \%creature_effects_by_id,
				},
				return_output => 1,
			}
		]
	);
}

sub select_action : Local {
	my ( $self, $c ) = @_;

	my $character = $c->model('DBIC::Character')->find( $c->req->param('character_id') );

	$character->last_combat_action( $c->req->param('action') );

	# Remove empty strings
	my @action_params = grep { $_ ne '' } $c->req->param('action_param');

	$character->last_combat_param1( $action_params[0] || '' );
	$character->last_combat_param2( $action_params[1] || '' );
	$character->update;
}

sub fight : Local {
	my ( $self, $c ) = @_;

	$c->stash->{creature_group} ||= $c->model('DBIC::CreatureGroup')->get_by_id( $c->stash->{party}->in_combat_with );

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		creature_group      => $c->stash->{creature_group},
		party               => $c->stash->{party},
		schema              => $c->model('DBIC')->schema,
		config              => $c->config,
		creatures_initiated => $c->stash->{creatures_initiated},
		log                 => $c->log,
		creatures_can_flee  => $c->stash->{party_location}->orb ? 0 : 1,    # Don't flee if there's an orb present
	);

	my $result = $battle->execute_round;

	$c->forward( '/combat/process_round_result', [$result] );
}

sub flee : Local {
	my ( $self, $c ) = @_;

	$c->stash->{creature_group} ||= $c->model('DBIC::CreatureGroup')->get_by_id( $c->stash->{party}->in_combat_with );

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		creature_group     => $c->stash->{creature_group},
		party              => $c->stash->{party},
		schema             => $c->model('DBIC')->schema,
		config             => $c->config,
		log                => $c->log,
		creatures_can_flee => $c->stash->{party_location}->orb ? 0 : 1,    # Don't flee if there's an orb present
		party_flee_attempt => 1,
	);

	my $result = $battle->execute_round;

	$c->forward( '/combat/process_flee_result', [$result] );

}

sub process_round_result : Private {
	my ( $self, $c, $result ) = @_;

	my $display_messages = $result->{display_messages};
	# We only want messages for opp1, since that's always the online party
	push @{ $c->stash->{combat_messages} }, @{ $display_messages->{1} };

	my @panels_to_refesh = ( 'messages', 'party', 'party_status' );
	if ( $result->{combat_complete} ) {

		push @panels_to_refesh, 'map';

		if ( !$c->stash->{party}->defunct && ! $result->{creatures_fled} ) {

			# Check for state of quests
			# TODO: should do this in offline combat too
			my $messages = $c->forward( '/quest/check_action', ['creature_group_killed'] );
			push @{ $c->stash->{combat_messages} }, @$messages;
		}

		# Force combat main to display final time
		$c->stash->{messages_path} = '/combat/main';

	}
	if ( $result->{creatures_fled} ) {
		push @panels_to_refesh, 'map';

		undef $c->stash->{creature_group};

	}
	if ( $result->{offline_party_fled} ) {
		push @panels_to_refesh, 'map';
	}

	$c->stash->{combat_complete} = $result->{combat_complete};

	$c->forward( '/panel/refresh', \@panels_to_refesh );
}

sub process_flee_result : Private {
	my ( $self, $c, $result ) = @_;

	my @panels_to_refesh = ( 'messages', 'party', 'party_status' );

	if ( $result->{party_fled} ) {
		$c->stash->{messages} = "You got away!";
		$c->log->debug("discarding party");
		
		$c->stash->{party}->discard_changes;
		$c->stash->{party_location} = $c->stash->{party}->location;

		undef $c->stash->{creature_group};
		push @panels_to_refesh, 'map';

		$c->forward( '/panel/refresh', \@panels_to_refesh );
	}
	else {
		push @{ $c->stash->{combat_messages} }, "You were unable to flee";

		$c->forward( '/combat/process_round_result', [$result] );
	}
}

sub target_list : Local {
	my ( $self, $c ) = @_;
	
	my $party = $c->stash->{party};
	
	my @opponents;
	if ( $party->combat_type eq 'creature_group' ) {
		@opponents = $c->model('DBIC::CreatureGroup')->get_by_id( $party->in_combat_with )->members;
	}
	elsif ( my $opponent_party = $party->in_party_battle_with ) {
		@opponents = $opponent_party->members;
	}
	elsif ( $party->combat_type eq 'garrison' ) {
		@opponents = $c->model('DBIC::Garrison')->get_by_id( $party->in_combat_with )->members;
	}	
		
	my @opponents_data;
	foreach my $opponent (@opponents) {
		next if $opponent->is_dead;
		push @opponents, {
			name => $opponent->name,
			id => $opponent->id,
		};
	}
	
	$c->res->body(to_json {opponents => \@opponents});
}

sub spell_list : Local {
	my ( $self, $c ) = @_;
	
	my $character = $c->model('DBIC::Character')->find(
		{
			character_id => $c->req->param('character_id'),
			party_id => $c->stash->{party}->id,
		}
	);
	
	return unless $character;	
	
	my %search_criteria = (
		memorised_today   => 1,
		number_cast_today => \'< memorise_count',
		character_id      => $character->id,
	);

	$c->stash->{party}->in_combat ? $search_criteria{'spell.combat'} = 1 : $search_criteria{'spell.non_combat'} = 1;

	my @spells = $c->model('DBIC::Memorised_Spells')->search( \%search_criteria, { prefetch => 'spell', }, );
		
	@spells = grep { $_->spell->can_cast($character) } @spells;
	
	my @spells_data;
	foreach my $mem_spell (@spells) {
		my $spell = $mem_spell->spell;
		push @spells_data, {
			spell_name => $spell->spell_name,
			number_left => $mem_spell->casts_left_today,
			id => $spell->id,
		};
	}
	
	$c->res->body(to_json {spells => \@spells_data});
}

sub spell_target_list : Local {
	my ( $self, $c ) = @_;
	
	my $character = $c->model('DBIC::Character')->find(
		{
			character_id => $c->req->param('character_id'),
			party_id => $c->stash->{party}->id,
		}
	);
	
	return unless $character;
	
	my $spell = $c->model('DBIC::Spell')->find({ spell_id => $c->req->param('spell_id') });
	
	my @targets;
	given ($spell->target) {
		when ('creature') {
			my $cg = $c->model('DBIC::CreatureGroup')->get_by_id( $c->stash->{party}->in_combat_with );
			@targets = $cg->members;
		}	
		when ('character') {
			@targets = $c->stash->{party}->members;
		}
	}
	
	my @target_data;
	foreach my $target (@targets) {
		push @target_data, {
			name => $target->name,
			id => $target->id,
		};	
	}
	
	$c->res->body(to_json {spell_targets => \@target_data});
}

1;
