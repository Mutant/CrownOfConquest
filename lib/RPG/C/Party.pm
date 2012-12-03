package RPG::C::Party;

use strict;
use warnings;
use base 'Catalyst::Controller';

use feature 'switch';

use Data::Dumper;
use DateTime;
use JSON;
use Text::Wrap;

use Carp;

use List::Util qw(shuffle);
use DateTime;
use DateTime::Event::Cron::Quartz;
use DateTime::Format::Duration;

sub main : Local {
	my ( $self, $c ) = @_;

    my $load_panel = $c->req->param('panel');

    $c->flash->{refresh_panels} = [ 'map', 'party', 'party_status', 'zoom', 'creatures', 'mini_map', 'online_parties', 'messages_notify' ];
    
    if (! $load_panel) { 
        $load_panel = 'party/init';
        unshift @{ $c->flash->{refresh_panels} }, 'messages';
    }
    
    # Don't update the last action of the party, since we'll do that when running the init
    $c->stash->{dont_update_last_action} = 1;
	
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'party/main.html',
				params   => {
					party  => $c->stash->{party},
					created_message => $c->stash->{created_message} || '',
					load_panel => $load_panel,
					message => $c->flash->{message},
					error => $c->flash->{error},
				},
			}
		]
	);
}

sub init : Local {
    my ( $self, $c ) = @_;

	if (! $c->flash->{refresh_panels}) {
        # Protect against flash not getting read properly
        $c->stash->{refresh_panels} = ['map', 'party', 'party_status', 'zoom', 'creatures', 'messages', 'mini_map', 'online_parties', 'messages_notify'];
	}
        
	$c->forward( '/panel/refresh' );   
} 

sub refresh_messages : Local {
	my ( $self, $c ) = @_;
	
	$c->forward( '/panel/refresh', ['messages', 'creatures'] );
}

sub refresh_party_list : Local {
	my ( $self, $c ) = @_;
	
	$c->forward( '/panel/refresh', ['party', 'messages'] );
}

sub sector_menu : Private {
	my ( $self, $c ) = @_;
		
	$c->stash->{message_panel_size} = 'small';

	my $creature_group = $c->stash->{creature_group};

	$creature_group ||= $c->stash->{party_location}->available_creature_group;

	my @graves = $c->model('DBIC::Grave')->search( { land_id => $c->stash->{party_location}->id, }, );

	my $dungeon = $c->model('DBIC::Dungeon')->find( { land_id => $c->stash->{party_location}->id, }, );
	
	# If they know about the dungeon we display a message in the sector menu.
	#  Note, they may not be able to enter the dungeon, but still know about it (i.e. they found the entrance
	#  when they were higher level, but have dropped levels since then). We still display them the message,
	#  but refuse entry.
	if ($dungeon) {
		my $mapped_sector = $c->stash->{mapped_sector} || $c->model('DBIC::Mapped_Sectors')->find_or_create(
	        {
	            party_id => $c->stash->{party}->id,
	            land_id  => $c->stash->{party_location}->id,
	        },
	    );
	
		$dungeon = undef unless $mapped_sector->known_dungeon;
	}

	my $parties_in_sector = $c->forward( 'parties_in_sector', [ $c->stash->{party_location}->id ] );

	$c->forward('/party/party_messages_check');
	
	$c->forward('/party/pending_mayor_check');

	my @adjacent_towns;
	if ( $c->stash->{party}->level >= $c->config->{minimum_raid_level} ) {	
		foreach my $town ($c->stash->{party_location}->get_adjacent_towns) {
            # Remove any the party is a mayor of
		    if ($town->mayor && $town->mayor->party_id != $c->stash->{party}->id) {
				push @adjacent_towns, $town;	
			}	
		}
	}

	my $can_build_garrison = 0;
	my $garrison           = $c->stash->{party_location}->garrison;
	if ( $c->stash->{party}->level >= $c->config->{minimum_garrison_level} ) {
		$can_build_garrison = $c->stash->{party_location}->garrison_allowed($c->stash->{party});
	}

	#  Determine if building can be built or is already built.  Also can seize or raze - for now, they all
	#    check the same level.
	my $building = $c->stash->{party_location}->building;

	my $can_build_building = 0;
	my $can_seize_building = 0;
	my $can_raze_building = 0;
	if ( $c->stash->{party}->level >= $c->config->{minimum_building_level} ) {
		$can_build_building = ! $building && $c->stash->{party_location}->building_allowed($c->stash->{party}->id) ? 1 : 0;
		
		if (! $garrison || $garrison->party_id == $c->stash->{party}->id) {
		    $can_seize_building = 1;
		    $can_raze_building = 1;
		}
	}

	my @items = $c->stash->{party_location}->items;
	
	my $kingdom = $c->stash->{party_location}->kingdom;
	
	my @corpses = $c->model('DBIC::Character')->search(
	   {
	       party_id => $c->stash->{party}->id,
	       status => 'corpse',
	       status_context => $c->stash->{party_location}->id,
	   }
    );

	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'party/sector_menu.html',
				params   => {
					party                  => $c->stash->{party},
					creature_group         => $creature_group,
					messages               => $c->flash->{messages} || $c->stash->{messages},
					day_logs               => $c->stash->{day_logs},
					location               => $c->stash->{party_location},
					orb                    => $c->stash->{party_location}->orb || undef,
					parties_in_sector      => $parties_in_sector,
					graves                 => \@graves,
					dungeon                => $dungeon,
					adjacent_towns         => \@adjacent_towns,
					had_phantom_dungeon    => $c->stash->{had_phantom_dungeon},
					garrison               => $garrison,
					can_build_garrison     => $can_build_garrison,
					can_build_building     => $can_build_building,
					can_seize_building     => $can_seize_building,
					can_raze_building      => $can_raze_building,
					building               => $building,
					items                  => \@items,
					kingdom                => $kingdom || undef,
					can_claim_land         => $c->stash->{party}->can_claim_land($c->stash->{party_location}),
					movement_cost          => $c->stash->{movement_cost} // 0,
					has_watcher            => $c->stash->{party}->has_effect('Watcher'),
					corpses                => \@corpses,
					bomb                   => $c->stash->{party_location}->bomb,
				},
				return_output => 1,
			}
		]
	);	
}

sub get_factor_comparison : Local {
 	my ( $self, $c ) = @_;  
 	
	# Check for a watcher effect
	my $has_watcher = $c->model('DBIC::Effect')->search(
        {
            'party_effect.party_id' => $c->stash->{party}->id,
            'effect_name' => 'Watcher',
            'time_left' => {'>', 0},
        },
        {
            join => 'party_effect',
        }
	)->count >= 1 ? 1 : 0;
	
	croak "Doesn't have watcher effect" unless $has_watcher;
	
	my $creature_group;
	if ($c->stash->{party}->dungeon_grid_id) {
	   $creature_group = $c->stash->{party}->dungeon_grid->available_creature_group;
	}
	else {	
	   $creature_group = $c->stash->{party_location}->available_creature_group;
	}
	
	croak "Doesn't have a CG in sector" unless $creature_group;

    my $factor_comparison = $creature_group->compare_to_party( $c->stash->{party} );
    
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'combat/factor_comparison.html',
				params   => {
					factor_comparison => $factor_comparison,
				},
			}
		]
	);    
   
}

sub pending_mayor_check : Private {
	my ( $self, $c ) = @_;
	
	my $town = $c->model('DBIC::Town')->find(
	   {
	       pending_mayor => $c->stash->{party}->id,
	   }
    );
    
    return unless $town;
    
	my $message = $c->forward(
		'RPG::V::TT',
		[
			{
				template => 'town/mayor_killed.html',
				params   => {
					town => $town,
					party => $c->stash->{party},
				},
				return_output => 1,
			}
		]
	);
	
	$c->forward('/panel/create_submit_dialog', 
		[
			{
				content => $message,
				submit_url => 'town/become_mayor',
				dialog_title => 'Become Mayor?',
			}
		],
	);   
}

sub parties_in_sector : Private {
	my ( $self, $c, $land_id, $dungeon_grid_id ) = @_;

	my %query_params = (
		party_id => { '!=', $c->stash->{party}->id },
		defunct  => undef,
	);

	if ($land_id) {
		$query_params{land_id} = $land_id;
		$query_params{dungeon_grid_id} = undef;
	}
	else {
		$query_params{dungeon_grid_id} = $dungeon_grid_id;
	}

	my @parties = $c->model('DBIC::Party')->search( \%query_params, 
	   {
	       prefetch => 'kingdom',
	   }, 
	);
	
	return \@parties;
}

sub party_messages_check : Private {
	my ( $self, $c ) = @_;

	# Get party messages
	my @party_messages = $c->model('DBIC::Party_Messages')->search(
		{
			alert_party => 1,
			party_id    => $c->stash->{party}->id,
			type        => 'standard',
		}
	);

	if (@party_messages) {
		foreach my $message (@party_messages) {
			$message->alert_party(0);
			$message->update;
		}

		$c->stash->{panel_messages} = [ map { $_->message } @party_messages ];
	}
}

sub list : Private {
	my ( $self, $c ) = @_;

	$c->stats->profile("Entered /party/list");

	my $party = $c->stash->{party};
	$party->discard_changes;

	# Because the party might have been updated by the time we get here, the chars are marked as dirty, and so have
	#  to be re-read.
	# TODO: check if an update has occured, and only re-read if it has
	my %null_fields = map { $_ => undef } RPG::Schema::Character->in_party_columns;
	my @characters = $c->model('DBIC::Character')->search(
		{
			party_id => $c->stash->{party}->id,
			%null_fields,
		},
		{
			prefetch => ['class', 'race'],
			order_by => 'party_order',
		}
	);	
			
	$c->stats->profile("Queried characters");
	
	my $in_combat = $party->in_combat ? 1 : 0;
	
	my %combat_params;
	if ($in_combat) {
		my (%opponents_by_id, %chars_by_id);
		
		# Get params for tooltips
		foreach my $character (@characters) {
			next unless $character->last_combat_param1;
			
			%opponents_by_id = map { $_->id => $_ } $party->opponents->members unless %opponents_by_id;
			%chars_by_id = map { $_->id => $_ } @characters unless %chars_by_id; 
						
			given ($character->last_combat_action) {
				when ('Attack') {
					$combat_params{$character->id} = [$opponents_by_id{$character->last_combat_param1}->name]
						if $opponents_by_id{$character->last_combat_param1};
				}
				when ('Cast') {
				    if ($character->last_combat_param1 eq 'autocast') {
				        $combat_params{$character->id} = ['(Auto)'];
				        next;   
				    }
				    
					my $spell = $c->model('DBIC::Spell')->find({spell_id => $character->last_combat_param1});
										
					my $target = $spell->target eq 'character' ? 
						$chars_by_id{$character->last_combat_param2} :
						$opponents_by_id{$character->last_combat_param2};
					
					next unless $target;
						
					$combat_params{$character->id} = [$target->name, $spell->spell_name];
				}
				when ('Use') {
					my $action = $character->get_item_action( $character->last_combat_param1 );
					my $target = $action->target eq 'character' ? 
						$chars_by_id{$character->last_combat_param2} :
						$opponents_by_id{$character->last_combat_param2};
						
					next unless $target;
						
					my $spell = $action->spell;
					my $spell_name = $spell->spell_name;
					$spell_name .= ' [' . $action->item->display_name . ']' if $action->can('item');
												
					$combat_params{$character->id} = [$target->name, $spell_name];					
				}
			}				
		}
	}
	
	$c->stats->profile("Got tooltips");

	my %broken_items_by_char_id = $c->stash->{party}->broken_equipped_items_hash;

	$c->stats->profile("Got Broken weapons");
	
	my @effects = $c->model('DBIC::Effect')->search(
	   {
	       'character_effect.character_id' => [map { $_->id } @characters],
	   },
	   {
	       prefetch => 'character_effect',
	   }
	);
	
	my %effects_by_character;
	foreach my $effect (@effects) {
        push @{ $effects_by_character{$effect->character_effect->character_id} }, $effect;
	}
	
	$c->stats->profile("Got effects");
	
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'party/party_list.html',
				params   => {
					party          => $party,
					in_combat      => $in_combat,
					characters     => \@characters,
					broken_items   => \%broken_items_by_char_id,
					combat_params  => \%combat_params,
					effects_by_character => \%effects_by_character,
				},
				return_output => 1,
			}
		]
	);
}

sub status : Private {
	my ( $self, $c ) = @_;

	my $party = $c->stash->{party};
	
	my $dt = DateTime->now();

	# TODO: should use config, but it still uses old style cron strings
	my $time_to_next_day = $self->_generate_date_string_from_quartz(
	   '0 5 4 * * ?', $dt, '%H hours, %M minutes', { minutes => 10 }, # Give it about 10 mins for the script to run.
	);
	
	my $time_to_next_turns = $self->_generate_date_string_from_quartz(
	   '0 0 * * * ?', $dt, '%M minutes',
	);

	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'party/status.html',
				params   => {
					party            => $party,
					location         => $c->stash->{party_location},
					day_number       => $c->stash->{today}->day_number,
					time_to_next_day => $time_to_next_day,
					time_to_next_turns => $time_to_next_turns,
				},
				return_output => 1,
			}
		]
	);
}

sub _generate_date_string_from_quartz {
    my $self = shift;
    my $quartz_string = shift;
    my $dt = shift;
    my $pattern = shift;   
    my $add_to_dt = shift;
    
    
    $dt->set_time_zone('local');
    
    my $event = DateTime::Event::Cron::Quartz->new($quartz_string);
    
    my $next_date = $event->get_next_valid_time_after($dt);
    if ($add_to_dt) {
        $next_date->add( %$add_to_dt );
    }
    
    my $dur = $next_date->subtract_datetime($dt);
    my $d = DateTime::Format::Duration->new( pattern => $pattern );
    
    return $d->format_duration_from_deltas( $d->normalise($dur) );
}

sub swap_chars : Local {
	my ( $self, $c ) = @_;

	return unless $c->req->param('target') && $c->req->param('moved');

	return if $c->req->param('target') == $c->req->param('moved');
	
	my %characters = map { $_->id => $_ } $c->stash->{party}->characters_in_party;

	# Moved char moves to the position of the target char
	my $moved_char_destination = $characters{ $c->req->param('target') }->party_order;
	my $moved_char_origin      = $characters{ $c->req->param('moved') }->party_order;

	# Is the moved char moving up or down?
	my $moving_up = $characters{ $c->req->param('moved') }->party_order > $moved_char_destination ? 1 : 0;

	# Move the rank separator if necessary.
	# We need to do this before adjusting for drop_pos
	my $sep_pos = $c->stash->{party}->rank_separator_position;

	#warn "moving_up: $moving_up, dest: $moved_char_destination, origin: $moved_char_origin, sep_pos: $sep_pos\n";
	if ( $moving_up && $moved_char_destination <= $sep_pos && $moved_char_origin >= $sep_pos ) {
		$c->stash->{party}->rank_separator_position( $sep_pos + 1 );
		$c->stash->{party}->update;
	}
	elsif ( !$moving_up && $moved_char_destination > $sep_pos && $moved_char_origin <= $sep_pos ) {
		$c->stash->{party}->rank_separator_position( $sep_pos - 1 );
		$c->stash->{party}->update;
	}

	# If the char was dropped after the destination and we're moving up, the destination is decremented
	$moved_char_destination++ if $moving_up && $c->req->param('drop_pos') eq 'after';

	# If the char was dropped before the destination and we're moving down, the destination is incremented
	$moved_char_destination-- if !$moving_up && $c->req->param('drop_pos') eq 'before';

	# Adjust all the chars' positions
	foreach my $character ( values %characters ) {
		if ( $character->id == $c->req->param('moved') ) {
			$character->party_order($moved_char_destination);
		}
		elsif ($moving_up) {
			next
				if $character->party_order < $moved_char_destination
					|| $character->party_order > $moved_char_origin;

			$character->party_order( $character->party_order + 1 );
		}
		else {
			next
				if $character->party_order < $moved_char_origin
					|| $character->party_order > $moved_char_destination;

			$character->party_order( $character->party_order - 1 );
		}

		$character->update;
	}

}

sub move_rank_separator : Local {
	my ( $self, $c ) = @_;

	my $target_char = $c->model('DBIC::Character')->find( { character_id => $c->req->param('target'), }, );

	my $new_pos = $c->req->param('drop_pos') eq 'after' ? $target_char->party_order : $target_char->party_order - 1;

	# We don't do anything if it's been dragged to the top. the GUI should prevent this from happening.
	return if $new_pos == 0;

	$c->stash->{party}->rank_separator_position($new_pos);
	$c->stash->{party}->update;
}

sub camp : Local {
	my ( $self, $c ) = @_;

	my $party = $c->stash->{party};

	if ( $party->turns >= RPG->config->{camping_turns} ) {
		$party->turns( $party->turns - RPG->config->{camping_turns} );
		$party->rest( $party->rest + 1 );
		$party->update;

		$c->stash->{messages} = "The party camps for a short period of time";
	}
	else {
		$c->stash->{error} = "You don't have enough turns left today to camp";
	}

	$c->forward( '/panel/refresh', [ 'messages', 'party_status' ] );
}

sub select_action : Local {
	my ( $self, $c ) = @_;

	# If we're in combat, we don't handle the action here
	if ( $c->stash->{party}->in_combat ) {
		$c->detach('/combat/select_action');
	}
	
	my $character = $c->model('DBIC::Character')->find(
		{
			character_id => $c->req->param('character_id'),
			party_id     => $c->stash->{party}->id,
		}
	);

	my $target;
	my $result;
	my $action;
	my $target_id;
	my $execute;
	my $spell;
	
	given ( $c->req->param('action') ) {
		when ('Cast') {
		    my $spell_id;
			( $spell_id, $target_id ) = $c->req->param('action_param');
			$action = $c->model('DBIC::Spell')->find($spell_id);
			$spell = $action;
			
			$execute = sub {
			    my $target = shift;			    
			    return $action->cast( $character, $target );
			}
		}
		when ('Use') {
		    my $action_id;
			( $action_id, $target_id ) = $c->req->param('action_param');
			$action = $character->get_item_action($action_id);
			$spell = $action->spell if $action->can('spell');
			
            $execute = sub {
			    my $target = shift;			    
			    return $action->use($target);
			}			
		}
	}		

    given ( $action->target ) {
        when ('character') {
            $target = $c->model('DBIC::Character')->find(
    			{
    				character_id => $target_id,
    				party_id     => $c->stash->{party}->id,
    			}
    		);
        }
     
        when ('special') {
            $target = $target_id;    
        }
        
        when ('sector') {
            if ($c->req->param('x') && $c->req->param('y')) {                
                $target = $c->model('DBIC::Land')->find(
                    {
                        x => $c->req->param('x'),
                        y => $c->req->param('y'),
                    }
                );
            }
            else {                
            	my $message = $c->forward(
            		'RPG::V::TT',
            		[
            			{
            				template => 'magic/select/sector.html',
            				params   => {
            					action => $c->req->param('action') // '',
            					character_id => $c->req->param('character_id') // '',
            					action_param => $c->req->param('action_param') // '',
            				},
            				return_output => 1,
            			}
            		]
            	);
                
            	$c->forward('/panel/create_submit_dialog', 
            		[
            			{
            				content => $message,
            				submit_url => 'party/select_action',
            				dialog_title => 'Select Sector',
            			}
            		],
            	);
            	
            	$c->detach( '/panel/refresh', [ 'messages' ] );
            }
        }
     
        default {
            $target = $c->stash->{party};    
        }
	}
	
	$result = $execute->($target);

	# HACK: refresh map screen if casting portal
	if ($spell && $spell->spell_name eq 'Portal') {
        push @{ $c->stash->{refresh_panels} }, 'map';
        push @{$c->stash->{panel_callbacks}}, {
            name => 'setMinimapVisibility',
            data => 1,
        };                
	}
	
	if ($result->custom->{raid_ended}) {
	    $c->forward('/castle/end_raid', [$result->custom->{castle}]);
	}

	my $message = $c->forward(
		'RPG::V::TT',
		[
			{
				template      => 'magic/spell_result.html',
				params        => { message => $result, },
				return_output => 1,
			}
		]
	);

	$c->stash->{messages} = $message;	

	$c->forward( '/panel/refresh', [ 'messages', 'party_status', 'party' ] );
}

sub scout : Local {
	my ( $self, $c ) = @_;

	my $party = $c->stash->{party};

	if ( $party->turns < 1 ) {
		$c->stash->{error} = "You do not have enough turns to scout";
		$c->forward( '/panel/refresh', ['messages'] );
		return;
	}

	my $avg_int = $party->average_stat('intelligence');

	my $chance_to_scout = $avg_int * $c->config->{scout_chance_per_int};
	$chance_to_scout = $c->config->{max_chance_scout} if $chance_to_scout > $c->config->{max_chance_scout};

	my @creatures;

	if ( Games::Dice::Advanced->roll('1d100') < $chance_to_scout ) {

		# Scout was successful, see what monsters are about
		my ( $start_point, $end_point ) = RPG::Map->surrounds( $party->location->x, $party->location->y, 3, 3, );

		my $search_rs = $c->model('DBIC::Land')->search(
			{
				x => { '>=', $start_point->{x}, '<=', $end_point->{x} },
				y => { '>=', $start_point->{y}, '<=', $end_point->{y} },
			},
			{ prefetch => 'creature_group', },
		);

		while ( my $sector = $search_rs->next ) {
			next if $sector->x == $party->location->x && $sector->y == $party->location->y;
			if ( $sector->creature_group ) {
				push @creatures, $sector;
			}
		}
	}

	$c->stash->{messages} = $c->forward(
		'RPG::V::TT',
		[
			{
				template      => 'party/scout_messages.html',
				params        => { creatures_scouted => \@creatures, },
				return_output => 1,
			}
		],
	);

	$party->turns( $party->turns - 1 );
	$party->update;

	$c->forward( '/panel/refresh', [ 'messages', 'party_status' ] );
}

sub new_party_message : Local {
	my ( $self, $c ) = @_;	

	$c->stash->{created_message} = $c->forward(
		'RPG::V::TT',
		[
			{
				template => 'party/complete.html',
				params   => {
					party => $c->stash->{party},
					town  => $c->stash->{party}->location->town,
				},
				return_output => 1,
			}
		]
	);
		
	$c->forward('/party/main');
}

sub disband : Local {
	my ( $self, $c ) = @_;
	
	if ($c->stash->{party}->in_combat) {
        $c->res->body("You can't disband your party while you're in combat");
        return;
	}

	# If this is a confirmation disband the party. Otherwise check for confirmation
	if ( $c->req->param('confirmed') ) {
		$c->stash->{party}->disband;
		$c->forward( '/panel/refresh', [[redirect => $c->config->{url_root}]] );
		return;
	}

	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'party/disband.html',
				params   => {},
			}
		]
	);
}

sub destroy_orb : Local {
	my ( $self, $c ) = @_;

	my $orb = $c->stash->{party_location}->orb;

	return unless $orb;

	my $party = $c->stash->{party};

	if ( $party->turns < 1 ) {
		$c->stash->{error} = "You do not have enough turns to destroy the orb";
		$c->forward( '/panel/refresh', ['messages'] );
		return;
	}

	$c->stash->{party_location}->discard_changes;

	unless ( $orb->can_destroy( $party->level ) ) {
		$c->stash->{messages} = "It's no good - you're just not powerful enough to destroy the Orb of " . $orb->name;
		$c->forward( '/panel/refresh', ['messages'] );
		return;
	}

	my $random_char = ( shuffle grep { $_->is_alive } $party->characters )[0];

	my $quest_messages = $c->forward( '/quest/check_action', [ 'orb_destroyed', $orb->id ] );

	$c->stash->{messages} = $c->forward(
		'RPG::V::TT',
		[
			{
				template => 'party/destroy_orb.html',
				params   => {
					random_char    => $random_char,
					orb            => $orb,
					quest_messages => $quest_messages,
				},
				return_output => 1,
			}
		],
	);

	$party->turns( $party->turns - 1 );
	$party->update;

	$orb->land_id(undef);
	$orb->update;

	$c->forward( '/panel/refresh', [ 'messages', 'party_status' ] );
}

sub pickup_item : Local {
	my ( $self, $c ) = @_;

	my $item = $c->model('DBIC::Items')->find( $c->req->param('item_id') );

	croak "Item not found" unless $item;

	my $party = $c->stash->{party};

	croak "Item not in sector" unless $item->land_id == $party->land_id;

	if ( $party->turns < 1 ) {
		$c->stash->{error} = "You do not have enough turns to pickup the item";
		$c->forward( '/panel/refresh', ['messages'] );
		return;
	}

	my $random_char = $party->give_item_to_character($item);

	$party->turns( $party->turns - 1 );
	$party->update;

	$c->stash->{messages} = $random_char->character_name . " picks up the " . $item->display_name(1);

	$c->forward( '/panel/refresh', [ 'messages', 'party_status' ] );
}

sub pickup_corpse : Local {
	my ( $self, $c ) = @_;
	
	my $character = $c->model('DBIC::Character')->find(
	   {
	       character_id => $c->req->param('character_id'),
	       party_id => $c->stash->{party}->id,
	   }
    );
    
    croak "Character not found" unless $character;
    
    my $party = $c->stash->{party};
    
	if ( $party->turns < 1 ) {
		$c->stash->{error} = "You do not have enough turns to pickup the corpse";
		$c->forward( '/panel/refresh', ['messages'] );
		return;
	}
	
	if ($party->is_full) {
		$c->stash->{error} = "You can't pick up the corpse because your party is full";
		$c->forward( '/panel/refresh', ['messages'] );
		return;
	}
	
	$party->turns( $party->turns - 1 );
	$party->update;
	
	$character->status(undef);
	$character->status_context(undef);
	$character->update;	
	
	$c->stash->{messages} = $character->character_name . " was returned to the party";
	
	$c->forward( '/panel/refresh', [ 'messages', 'party_status', 'party' ] );
        
}

sub enter_dungeon : Local {
	my ( $self, $c ) = @_;

	my $dungeon = $c->model('DBIC::Dungeon')->find( { land_id => $c->stash->{party_location}->id, }, );

	unless ( $dungeon->party_can_enter( $c->stash->{party} ) ) {
		$c->stash->{error} = "Your party is not high enough level to enter this dungeon";
		$c->forward( '/panel/refresh', [ 'messages' ]);
		return;
	}

	# Reset zoom level
	$c->session->{zoom_level} = 2;

	my $start_sector = $c->model('DBIC::Dungeon_Grid')->find(
		{
			'dungeon_room.dungeon_id' => $dungeon->id,
			'dungeon_room.floor'      => 1,
			'stairs_up'               => 1,
		},
		{ join => 'dungeon_room', }
	);

	$c->stash->{party}->dungeon_grid_id( $start_sector->id );
	$c->stash->{party}->update;
	
    push @{$c->stash->{panel_callbacks}}, {
        name => 'setMinimapVisibility',
        data => 0,
    };

	$c->forward( '/panel/refresh', [ 'map', 'messages', 'party_status', 'zoom', 'party', 'creatures' ] );
}

sub zoom : Private {
	my ( $self, $c ) = @_;

	$c->session->{zoom_level} ||= 2;

	return $c->forward(
		'RPG::V::TT',
		[
			{
				template => 'map/main_screen_zoom.html',
				params   => {
					zoom_level => $c->session->{zoom_level}
				},
				return_output => 1,
			}
		]
	);
}

sub zoom_change : Local {
	my ( $self, $c ) = @_;

	$c->session->{zoom_level} = $c->req->param('zoom_level');

	$c->forward( '/panel/refresh', [ 'map', 'zoom', 'messages' ] );
}

sub claim_land : Local {
	my ( $self, $c ) = @_;

	die "Can't claim this land\n" unless $c->stash->{party}->can_claim_land($c->stash->{party_location});
	
	if ($c->stash->{party}->turns < 10) {
        $c->stash->{error} = "You do not have enough turns left to claim more land";
		$c->forward( '/panel/refresh', [ 'messages' ]);
		return;
	}
	
	$c->stash->{party}->turns($c->stash->{party}->turns - 1);
	$c->stash->{party}->update;
	
	$c->stash->{party_location}->kingdom_id($c->stash->{party}->kingdom_id);
	$c->stash->{party_location}->update;
	
    my $day_stats = $c->model('DBIC::Party_Messages')->find_or_create(
        {
            day_id => $c->stash->{today}->id,
            party_id => $c->stash->{party}->id,
            type => 'claim_land_count',
        },
    );
    $day_stats->message($day_stats->message+1);
    $day_stats->update;
	
	my $kingdom = $c->stash->{party}->kingdom;
	my $land_count = $kingdom->sectors->count;
	if ($kingdom->highest_land_count < $land_count) {
	   $kingdom->highest_land_count($land_count);
	   $kingdom->highest_land_count_day_id($c->stash->{today}->id);
	   $kingdom->update;
	}
	
	my $message = "You claim this sector for the Kingdom of " . $c->stash->{party}->kingdom->name;
	
	$message .= " You've claimed " . $day_stats->message . " land today, out of your maximum allowed of " . $c->config->{max_land_claimed_per_day};
	
	$c->stash->{messages} = [$message];
	
    my $quest_messages = $c->forward( '/quest/check_action', [ 'claimed_land', $c->stash->{party_location}->id ] );
    push @{ $c->stash->{messages} }, @$quest_messages if $quest_messages;
	
	$c->forward( '/panel/refresh', [ 'messages', 'party_status' ] );
}

sub online : Private {
	my ( $self, $c ) = @_;
	
	# Make sure logged in party is included in online parties
    $c->stash->{party}->last_action( DateTime->now() );
    $c->stash->{party}->update;		
		
    # Get parties online
    my @parties_online = $c->model('DBIC::Party')->search(
        {
            last_action => { '>=', DateTime->now()->subtract( minutes => $c->config->{online_threshold} ) },
            defunct     => undef,
            name => { '!=', '' },
        },
        {
            order_by => 'last_action desc',
        }
    );
        
	return $c->forward(
		'RPG::V::TT',
		[
			{
				template => 'party/online.html',
				params   => {
					parties_online => \@parties_online,
					foo => 1,
				},
				return_output => 1,
			}
		]
	);      
}

sub profile : Local {
	my ( $self, $c ) = @_;
	
	my $party = $c->model('DBIC::Party')->find(
	   {
	       party_id => $c->req->param('party_id'),
	       defunct => undef,
	   },
	   {
	       prefetch => 'player',
	   }
	   
	);
	
	$c->stash->{message_panel_size} = 'large';
	$c->stash->{bring_messages_to_front} = 1;
	
	croak "Party not found" unless $party;   
	
    my $profile = $c->forward(
		'RPG::V::TT',
		[
			{
				template => 'party/profile.html',
				params   => {
					party => $party,
					mayors_count => scalar $party->mayors // 0,
					buildings_count => scalar $party->get_owned_buildings // 0,
				},
				return_output => 1,
			}
		]
	); 	
	
	$c->forward( '/panel/refresh', [ [ 'messages', $profile ] ] );
}

1;
