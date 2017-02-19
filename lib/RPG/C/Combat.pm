package RPG::C::Combat;

use strict;
use warnings;
use base 'Catalyst::Controller';

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

	$c->forward( 'execute_attack', [$creature_group] );

}

sub execute_attack : Private {
	my ( $self, $c, $creature_group ) = @_;
	
	if ($c->stash->{party}->turns <= 0) {
		$c->stash->{error} = $c->forward('/party/not_enough_turns',['attack the creatures']);
		$c->forward( '/panel/refresh', ['messages'] );
		return;   
	}

	if ($creature_group) {
	    if (! $c->req->param('attack_confirmed')) {
            my $confirm_attack = $creature_group->level > $c->stash->{party}->level && !$creature_group->party_within_level_range( $c->stash->{party} );
            
            if ($confirm_attack) {
            	my $message = $c->forward(
            		'RPG::V::TT',
            		[
            			{
            				template => 'combat/confirm_attack.html',
            				params   => {},
            				return_output => 1,
            			}
            		]
            	);
            	
            	my $submit = $c->stash->{party}->dungeon_grid_id ? 'dungeon/combat/party_attacks' : 'combat/party_attacks';
            	
            	$c->forward('/panel/create_submit_dialog', 
            		[
            			{
            				content => $message,
            				submit_url => $submit,
            				dialog_title => 'Confirm Attack?',
            			}
            		],
            	);
            	
            	$c->forward( '/panel/refresh', ['messages'] );
            	return;
            }
	    }
	    
		$c->stash->{creature_group} = $creature_group;

		$c->stash->{party}->initiate_combat( $creature_group );

		$c->forward( '/panel/refresh', [ 'messages', 'party' ] );
	}
	else {
		$c->stash->{error} = "The creatures have moved, or have been attacked by someone else.";
		$c->forward( '/panel/refresh', ['messages'] );
	}
}

sub switch : Private {
	my ( $self, $c ) = @_;
	
	my $party = $c->stash->{party};
	
	return unless $party->in_combat_with;
	
	if ($party->combat_type eq 'creature_group') {
		return $c->forward('/combat/main');
	}
	elsif ($party->combat_type eq 'garrison') {
		return $c->forward('/garrison/combat/main');
	}
}

sub main : Local {
	my ( $self, $c ) = @_;

	my $creature_group = $c->stash->{creature_group};
	if ( !$c->stash->{combat_complete} && !$creature_group ) {
		$creature_group = $c->model('DBIC::CreatureGroup')->get_by_id( $c->stash->{party}->in_combat_with );
	}

	my $orb;
	if ( $c->stash->{creatures_initiated} && !$c->stash->{party}->dungeon_grid_id ) {
		$orb = $c->stash->{party_location}->orb;
	}

	return $c->forward(
		'RPG::V::TT',
		[
			{
				template => 'combat/main.html',
				params   => {
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

sub display_opponents : Local {
	my ( $self, $c ) = @_;
			
	# It's called 'creature_group' even though it could be a party or garrison
	my $creature_group = $c->stash->{creature_group};
	
	return unless $creature_group;

	# Load effects, to make sure they're current (i.e. include current round)
    my %ids;
    $ids{creature}  = [ map { $_->id } grep { ! $_->is_character } $creature_group->members ];
    $ids{character} = [ map { $_->id } grep { $_->is_character   } $creature_group->members ];   
	
	my %effects_by_id;
	for my $type (keys %ids) {
	    if (my @ids = @{ $ids{$type} }) {
        	my @effects = $c->model('DBIC::Effect')->search(
        		{
        		    $type . '_effect.' . "${type}_id" => \@ids,
        			'combat' => 1,
        		},
        		{ 
        		    prefetch => [$type . '_effect'],
        		}
        	);
        	
        	foreach my $effect (@effects) {
        	    my $effect_method = $type . '_effect';
        	    my $id_method = $type . '_id';
                my $id = $effect->$effect_method->$id_method;
                push @{ $effects_by_id{$type}{$id} }, $effect;
        	}	        
	    } 
	}
	
	$c->stats->profile('Got effects');

	return $c->forward(
		'RPG::V::TT',
		[
			{
				template => 'combat/creature_group.html',
				params   => {
					creature_group         => $creature_group,
					effects_by_id => \%effects_by_id,
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
	
	$c->stats->profile('In /combat/fight');

	$c->stash->{creature_group} ||= $c->model('DBIC::CreatureGroup')->get_by_id( $c->stash->{party}->in_combat_with );
	
	$c->stats->profile('Got CG');

	my $battle = RPG::Combat::CreatureWildernessBattle->new(
		creature_group      => $c->stash->{creature_group},
		party               => $c->stash->{party},
		schema              => $c->model('DBIC')->schema,
		config              => $c->config,
		creatures_initiated => $c->stash->{creatures_initiated},
		log                 => $c->log,
		creatures_can_flee  => $c->stash->{party_location}->orb ? 0 : 1,    # Don't flee if there's an orb present
	);
	
	$c->stats->profile('Created battle');

	my $result = $battle->execute_round;
	
	$c->stats->profile('Executed round');

	$c->forward( '/combat/process_round_result', [$result] );
	
	$c->stats->profile('Processed round result');
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

	my @panels_to_refesh = ( 'messages', 'party_status' );
	if ( $result->{combat_complete} ) {

		if ( ($result->{losers} && !$c->stash->{party}->is($result->{losers})) && ! $result->{creatures_fled} ) {

			# Check for state of quests
			# TODO: should do this in offline combat too
			my $messages = $c->forward( '/quest/check_action', ['creature_group_killed'] );
			push @{ $c->stash->{combat_messages} }, @$messages;
		}
		
		if ($result->{losers} && $c->stash->{party}->is($result->{losers})) {
		    # Party lost, refresh whole map
		    $c->stash->{party}->discard_changes;
		    $c->stash->{party_location} = $c->stash->{party}->location;
            push @panels_to_refesh, 'map';
            
            $c->stash->{panel_messages} = "The party was wiped out! We awake in a town, clearly brought here by a sympathetic healer. ".
                "<br>However, we may have lost some of our characters and equipment." .
                "<br>Note, the party can be restarted by clicking on Tools, and clicking 'Disband Party'."; 
		}
					
		# Force combat main to display final time
		$c->stash->{messages_path} = '/combat/main';

	}
	if ( $result->{creatures_fled} ) {
		push @panels_to_refesh, ('creatures');

		undef $c->stash->{creature_group};
	}
		
	$c->stash->{combat_complete} = $result->{combat_complete};
	
	if ($c->stash->{combat_complete} && $c->stash->{party}->dungeon_grid_id) {
	    # If combat is over and we're in a dungeon, refresh the map screen
	    push @panels_to_refesh, 'map';	   
	}
	
	$c->stash->{message_panel_size} = 'large';
	
	push @{$c->stash->{panel_callbacks}}, { name => 'postRound' };

	$c->forward( '/panel/refresh', \@panels_to_refesh );
}

sub process_flee_result : Private {
	my ( $self, $c, $result ) = @_;

	if ( $result->{party_fled} ) {
	    my @panels_to_refesh = ( 'messages', 'party', 'party_status', 'map', 'creatures' );
	    
		$c->stash->{messages} = "You got away!";
		$c->log->debug("discarding party");
		
		$c->stash->{party}->discard_changes;
		$c->stash->{party_location} = $c->stash->{party}->location;

		undef $c->stash->{creature_group};

		$c->forward( '/panel/refresh', \@panels_to_refesh );
	}
	else {
		push @{ $c->stash->{combat_messages} }, "You were unable to flee";

		$c->forward( '/combat/process_round_result', [$result] );
	}
}

sub refresh_combatants : Local {
    my ( $self, $c ) = @_;
    
    $c->stash->{creature_group} = $c->stash->{party}->opponents;
    
    $c->forward( '/panel/refresh', ['party', 'creatures'] );   
}

sub target_list : Local {
	my ( $self, $c ) = @_;
	
	my $party = $c->stash->{party};
	
	my @opponents = $party->opponents->members;
	
	my @opponents_data;
	foreach my $opponent (@opponents) {
		next if $opponent->is_dead;
		push @opponents_data, {
			name => $opponent->name,
			id => $opponent->id,
		};
	}
	
	$c->res->body(to_json {opponents => \@opponents_data});
}

sub cast_list : Local {
	my ( $self, $c ) = @_;
	
	my $character = $c->model('DBIC::Character')->find(
		{
			character_id => $c->req->param('character_id'),
			party_id => $c->stash->{party}->id,
		}
	);
	
	return unless $character;	
	
	my @spells = $character->castable_spells($c->stash->{party}->in_combat ? 1 : 0);
		
	@spells = grep { $_->spell->can_cast($character) } @spells;
	
	my @spells_data;
	foreach my $mem_spell (@spells) {
		my $spell = $mem_spell->spell;
		push @spells_data, {
			label => $spell->spell_name . " (" . $mem_spell->casts_left_today . ")",
			id => $spell->id,
			target => $spell->target,
		};
	}
	
	my $autocast = $c->stash->{party}->in_combat && $character->online_cast_chance > 0 ? 1 : 0;
	$c->res->body(to_json {list => \@spells_data, autocast => $autocast});
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
	
	$c->forward('build_target_list', [$spell]);

}

sub build_target_list : Private {
	my ( $self, $c, $spell, $item ) = @_;
	
	my @targets;
    my @target_data;
	for ($spell->target) {
		if ($_ eq 'creature') {
			@targets = $c->stash->{party}->opponents->members;
		}	
		if ($_ eq 'character') {
			@targets = $c->stash->{party}->members;
		}
		if ($_ eq 'special') {
            @target_data = $item->target_list;   
		}
	}
	
	if (! @target_data) {
    	foreach my $target (@targets) {
    	    next if $target->is_dead;
    		next unless $spell->can_be_cast_on($target);
    		push @target_data, {
    			name => $target->name,
    			id => $target->id,
    		};	
    	}
	}
	
	my $spell_name;
	if ($item) {
		$spell_name .= ' [' . $item->display_name . ']';	
	}
	else {
        $spell_name = $spell->spell_name;
	}
	
	$c->res->body(to_json {spell_targets => \@target_data, spell_name => $spell_name});	
}

sub use_list : Local {
	my ( $self, $c ) = @_;
	
	my $character = $c->model('DBIC::Character')->find(
		{
			character_id => $c->req->param('character_id'),
			party_id => $c->stash->{party}->id,
		}
	);
	
	return unless $character;
	
	my @actions;
	foreach my $action ($character->get_item_actions($c->stash->{party}->in_combat)) {
		push @actions, {
			id => $action->id,
			label => $action->label,
			target => $action->target,
		};
	}
	
	$c->res->body(to_json {list => \@actions});
		
}

sub use_target_list : Local {
	my ( $self, $c ) = @_;
	
	my $character = $c->model('DBIC::Character')->find(
		{
			character_id => $c->req->param('character_id'),
			party_id => $c->stash->{party}->id,
		}
	);
	
	return unless $character;
	
	my $action = $character->get_item_action($c->req->param('action_id'));
	
	$c->forward('build_target_list', [$action->can('spell') ? $action->spell : $action, $action->can('item') ? $action->item : $action]);

}

1;
