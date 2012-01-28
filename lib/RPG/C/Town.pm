package RPG::C::Town;

use strict;
use warnings;
use base 'Catalyst::Controller';

use feature qw(switch);

use Math::Round qw(round);
use JSON;
use List::Util qw(shuffle);
use Carp;
use DateTime;

sub begin : Private {
    my ( $self, $c ) = @_;
    
    $c->stash->{message_panel_size} = 'large';
}

sub main : Local {
	my ( $self, $c, $return_output ) = @_;

	my $town = $c->stash->{party_location}->town;

	my $parties_in_sector = $c->forward( '/party/parties_in_sector', [ $c->stash->{party_location}->id ] );

	my $mayor = $c->model('DBIC::Character')->find(
		{
			mayor_of => $town->id,
		},
		{
			prefetch => 'party',
		},
	);

	$c->forward('/party/party_messages_check');

	my $party_town = $c->model('DBIC::Party_Town')->find_or_create(
		{
			party_id => $c->stash->{party}->id,
			town_id  => $town->id,
		},
	);	

	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'town/main.html',
				params   => {
					town              => $town,
					day_logs          => $c->stash->{day_logs},
					party_messages    => $c->stash->{party_messages},
					messages          => $c->stash->{messages},
					parties_in_sector => $parties_in_sector,
					prestige          => $party_town->prestige,
					allowed_discount  => $town->discount_type && $party_town->prestige >= $town->discount_threshold ? 1 : 0,
					mayor             => $mayor,
					party             => $c->stash->{party},
					current_election  => $town->current_election,
					kingdom           => $town->location->kingdom,
					sewer             => $town->sewer,
				},
				return_output => $return_output || 1,
			}
		]
	);
}

sub back_to_main : Local {
	my ( $self, $c ) = @_;

	my $panel = $c->forward( 'main', [1] );

	push @{ $c->stash->{refresh_panels} }, [ 'messages', $panel ];

	$c->forward('/panel/refresh');
}

sub shop_list : Local {
	my ( $self, $c ) = @_;

	my $panel = $c->forward(
		'RPG::V::TT',
		[
			{
				template      => 'town/shop_list.html',
				params        => { town => $c->stash->{party_location}->town, },
				return_output => 1,
			}
		]
	);

	push @{ $c->stash->{refresh_panels} }, [ 'messages', $panel ];

	$c->forward('/panel/refresh');
}

sub leave : Local {
    my ( $self, $c ) = @_;
    
    my $town = $c->stash->{party_location}->town;
    
	my $panel = $c->forward(
		'RPG::V::TT',
		[
			{
				template      => 'town/leave.html',
				params        => { town => $town, },
				return_output => 1,
			}
		]
	);
	
	if ($c->stash->{party}->level <= $c->config->{max_party_level_leave_town_warning}) {
        $c->stash->{panel_messages} = "The wilderness is full of dangerous monsters.\n\n" . 
            "You may want to level up your party in the sewers before leaving the safety of town!";
	}
    
    push @{ $c->stash->{refresh_panels} }, [ 'messages', $panel ];
    
    $c->stash->{message_panel_size} = 'small';   
    
    $c->forward('/panel/refresh');
}

sub healer : Local {
	my ( $self, $c ) = @_;

	my $town = $c->stash->{party_location}->town;

	my @characters = $c->stash->{party}->characters_in_party;

	my @dead_chars = grep { $_->is_dead } @characters;

	my $cost_to_heal = $c->forward( 'calculate_heal_cost', [$town] );

	my $panel = $c->forward(
		'RPG::V::TT',
		[
			{
				template => 'town/healer.html',
				params   => {
					party           => $c->stash->{party},
					cost_to_heal    => $cost_to_heal,
					dead_characters => \@dead_chars,
					town            => $town,
					messages        => $c->stash->{messages},
				},
				return_output => 1,
			}
		]
	);

	push @{ $c->stash->{refresh_panels} }, [ 'messages', $panel ];

	$c->forward('/panel/refresh');
}

sub heal_party : Local {
	my ( $self, $c ) = @_;

	my $town = $c->stash->{party_location}->town;

	my @characters = $c->stash->{party}->characters_in_party;

	my $cost_to_heal = $c->forward( 'calculate_heal_cost', [$town] );

	my $amount_to_spend = defined $c->req->param('gold') ? $c->req->param('gold') : $cost_to_heal;

	my $percent_to_heal = 0;
	unless ( $cost_to_heal == 0 ) {
		$percent_to_heal = $amount_to_spend / $cost_to_heal * 100;
	}
	
	$amount_to_spend = $cost_to_heal if $amount_to_spend > $cost_to_heal;
	$percent_to_heal = 100 if $percent_to_heal > 100;

	if ( $amount_to_spend <= $c->stash->{party}->gold ) {
		$c->stash->{party}->gold( $c->stash->{party}->gold - $amount_to_spend );
		$c->stash->{party}->update;

		foreach my $character (@characters) {
			next if $character->is_dead;

			my $amount_to_heal = int( $character->max_hit_points - $character->hit_points ) * ( $percent_to_heal / 100 );

			$character->hit_points( $character->hit_points + $amount_to_heal );
			$character->update;
		}

		if ( $percent_to_heal == 100 ) {
			$c->stash->{messages} = 'The party has been fully healed';
		}
		else {
			$c->stash->{messages} = "The party has been healed for $amount_to_spend gold";
		}
	}
	else {
		if ( $c->req->param('gold') ) {
			$c->stash->{error} = "You only have " . $c->stash->{party}->gold . " gold. You can't heal for more gold than you have!";
		}
		else {
			$c->stash->{error} = "You don't have enough gold for a full heal. Try a partial heal";
		}
	}

	push @{ $c->stash->{refresh_panels} }, ( 'party', 'party_status' );

	$c->forward('/town/healer');
}

sub resurrect : Local {
	my ( $self, $c ) = @_;
	
	my @characters = $c->stash->{party}->characters_in_party;

	my @dead_chars = grep { $_->is_dead } @characters;

	my ($char_to_res) = grep { $_->id == $c->req->param('character_id') } @dead_chars;	

	$c->forward('res_impl', [$char_to_res]);

	$c->forward('/town/healer');
}

sub res_from_morgue : Local {
	my ( $self, $c ) = @_;
	
	my $town = $c->stash->{party_location}->town;
	
	my @characters = $c->stash->{party}->characters_in_party;
	my $character = $c->model('DBIC::Character')->find(
		{
			character_id => $c->req->param('character_id'),
			party_id => $c->stash->{party}->id,
			status => 'morgue',
			status_context => $town->id,
		}
	);
	
	croak "Invalid character" unless $character;
	
	if (scalar @characters >= $c->config->{max_party_characters}) {
		$c->stash->{error} = "You already have " . $c->config->{max_party_characters} 
			. " characters in your party - you can't add another from the morgue";
	}
	else {
		if ($c->forward('res_impl', [$character])) {
			$character->status(undef);
			$character->status_context(undef);
			$character->update;	
			$c->stash->{party}->adjust_order;
		}		
	}
	
	$c->forward('/town/cemetery');
	
}

sub res_impl : Private {
	my ( $self, $c, $char_to_res ) = @_;

	my $town = $c->stash->{party_location}->town;
	
	my $ressed = 0;

	if ($char_to_res) {
		if ( $char_to_res->resurrect_cost > $c->stash->{party}->gold ) {
			$c->stash->{error} = "You don't have enough gold to resurrect " . $char_to_res->character_name;
		}
		else {
            my $message = $char_to_res->resurrect($town);
            
            $c->stash->{party}->discard_changes;

			$c->stash->{messages} = $message;
			
			$ressed = 1;
		}
	}

	push @{ $c->stash->{refresh_panels} }, ( 'party', 'party_status' );
	
	return $ressed;	
}

sub calculate_heal_cost : Private {
	my ( $self, $c, $town ) = @_;

	my $per_hp_heal_cost = $town->heal_cost_per_hp;

	my $cost_to_heal = 0;

	foreach my $character ( $c->stash->{party}->characters_in_party ) {
		next if $character->is_dead;

		$cost_to_heal += $per_hp_heal_cost * ( $character->max_hit_points - $character->hit_points );
	}

	if ( $town->discount_type && $town->discount_type eq 'healer' && $c->stash->{party}->prestige_for_town($town) >= $town->discount_threshold ) {
		$cost_to_heal = round( $cost_to_heal * ( 100 - $town->discount_value ) / 100 );
	}

	return $cost_to_heal;
}

sub news : Local {
	my ( $self, $c, $town, $day_range ) = @_;

	my $panel = $c->forward('generate_news', [$c->stash->{party_location}->town, $c->config->{news_day_range}]);
	
	$panel .= $c->forward(
		'RPG::V::TT',
		[
			{
				template => 'town/town_footer.html',
				return_output => 1,
			}
		]
	);
	
	push @{ $c->stash->{refresh_panels} }, [ 'messages', $panel ];

	$c->forward('/panel/refresh');
}

sub generate_news : Private {
	my ( $self, $c, $town, $day_range ) = @_;

	my $current_day = $c->stash->{today}->day_number;

	my @logs = $c->model('DBIC::Town_History')->recent_history($town->id, 'news', $current_day, $day_range);

	my $news = $c->forward(
		'RPG::V::TT',
		[
			{
				template => 'town/news.html',
				params   => {
					town => $town,
					logs => \@logs,
				},
				return_output => 1,
			}
		]
	);
	
	return $news;
}

sub quests : Local {
	my ( $self, $c ) = @_;

	# See if party has a quest for this town
	my $party_quest = $c->model('DBIC::Quest')->find(
		{
			town_id  => $c->stash->{party_location}->town->id,
			party_id => $c->stash->{party}->id,
			status   => 'In Progress',
		},
	);

	# If the have a quest to complete, send them there now
	if ( $party_quest && $party_quest->ready_to_complete ) {
		$c->detach( '/quest/complete_quest', [$party_quest] );
	}

	# Check for quest actions which can be triggered by a visit to the town hall
	my $quest_messages = $c->forward( '/quest/check_action', ['townhall_visit'] );

	my $allowed_more_quests = $c->stash->{party}->allowed_more_quests;

	my @quests;

	# If they don't have a quest, load in available quests
	if ( !$party_quest && $allowed_more_quests ) {
		@quests = shuffle $c->model('DBIC::Quest')->search(
			{
				town_id  => $c->stash->{party_location}->town->id,
				party_id => undef,
			},
			{ prefetch => 'type', },
		);
	}

	my $panel = $c->forward(
		'RPG::V::TT',
		[
			{
				template => 'town/quests.html',
				params   => {
					town                => $c->stash->{party_location}->town,
					quests              => \@quests,
					party_quest         => $party_quest,
					allowed_more_quests => $allowed_more_quests,
					quest_messages      => $quest_messages,
				},
				return_output => 1,
			}
		]
	);

	push @{ $c->stash->{refresh_panels} }, [ 'messages', $panel ];

	$c->forward('/panel/refresh');
}

sub cemetery : Local {
	my ( $self, $c ) = @_;

	my $town = $c->model('DBIC::Town')->find( { land_id => $c->stash->{party_location}->id } );

	my @graves = $c->model('DBIC::Grave')->search( { land_id => $c->stash->{party_location}->id, }, );
	
	my @morgue = $c->model('DBIC::Character')->search(
		{
			'status' => 'morgue',
			'status_context' => $town->id,
		}
	);

	my $panel = $c->forward(
		'RPG::V::TT',
		[
			{
				template      => 'town/cemetery.html',
				params        => { 
					graves => \@graves,
					morgue => \@morgue,
					party => $c->stash->{party},					 
				},
				return_output => 1,
			}
		]
	);

	push @{ $c->stash->{refresh_panels} }, [ 'messages', $panel ];

	$c->forward('/panel/refresh');
}

sub enter : Local {
	my ( $self, $c ) = @_;

	my $town = $c->model('DBIC::Town')->find( { land_id => $c->req->param('land_id') } );

	unless ( $c->forward( '/map/can_move_to_sector', [ $town->location ] ) ) {
	    
	    $c->stash->{message_panel_size} = 'small';

		# Can't move to this town for whatever reason
		$c->detach( '/panel/refresh', [ 'messages', 'party_status' ] );
	}

    my ($can_enter, $reason) = $town->party_can_enter($c->stash->{party});

	# Check if they have really low prestige, and need to be refused.
	if (! $can_enter) {		    
        $c->stash->{message_panel_size} = 'small';
		    
		$c->stash->{panel_messages} = $reason;

		$c->detach( '/panel/refresh', ['messages'] );
	}

	my $cost = $town->tax_cost( $c->stash->{party} );
	
	my $party_town = $c->model('DBIC::Party_Town')->find_or_create(
		{
			party_id => $c->stash->{party}->id,
			town_id  => $town->id,
		},
	);	

	# Pay tax, if necessary
	if ( $cost->{gold} ) {
		croak "Payment method not specified" unless $c->req->param('payment_method');

		if ( $c->req->param('payment_method') eq 'gold' ) {
			if ( $cost->{gold} > $c->stash->{party}->gold ) {
				$c->stash->{panel_messages} = ["You don't have enough gold to pay the tax"];
				$c->detach( '/panel/refresh', ['messages'] );
			}

			$c->stash->{party}->gold( $c->stash->{party}->gold - $cost->{gold} );
		}
		else {
			if ( $cost->{turns} > $c->stash->{party}->turns ) {
			    $c->stash->{message_panel_size} = 'small';
				$c->stash->{panel_messages} = ["You don't have enough turns to pay the tax"];
				$c->detach( '/panel/refresh', ['messages'] );
			}

			$c->stash->{party}->turns( $c->stash->{party}->turns - $cost->{turns} );
		}

		$c->stash->{party}->update;

		# Record payment (Always recorded in gold)
		$party_town->tax_amount_paid_today( $cost->{gold} );
		
		$town->increase_gold($cost->{gold});
		$town->update;

		$party_town->increment_prestige;
		$party_town->update;
	}

	$c->stash->{entered_town} = 1;

	$c->forward('/map/move_to', [{'refresh_current' => 1}]);
}

sub raid : Local {
	my ( $self, $c ) = @_;

	croak "Not high enough level for that" unless $c->stash->{party}->level >= $c->config->{minimum_raid_level};

	my $town = $c->model('DBIC::Town')->find( { town_id => $c->req->param('town_id') } );

	croak "Invalid town id" unless $town;

	croak "Not next to that town" unless $c->stash->{party_location}->next_to( $town->location );
	
	croak "Can't raid a town you're mayor of" if $town->mayor && $town->mayor->party_id == $c->stash->{party}->id;

	my $start_sector = $c->model('DBIC::Dungeon_Grid')->find(
		{
			'dungeon.land_id' => $town->land_id,
			'stairs_up'       => 1,
			'dungeon.type'    => 'castle',
		},
		{
			join => { 'dungeon_room' => 'dungeon' },
		}
	);

	confess "Castle not found for town " . $town->id unless $start_sector;

	my $party_town = $c->model('DBIC::Party_Town')->find_or_create(
		{
			town_id  => $town->id,
			party_id => $c->stash->{party}->id,
		}
	);
	
	if (($party_town->raids_today // 0) > $c->config->{max_raids_per_day}) {
	   $c->stash->{error} = "You've raided this town too many times today";
	   $c->forward( '/panel/refresh', [ 'messages' ]);
	   return;
	}	
	
	my $mayor = $town->mayor;
    # If the mayor is owned by a party, see if this party is doing coop with them
    if ( $mayor && ! $mayor->is_npc && $c->stash->{party}->is_suspected_of_coop_with( $mayor->party ) ) {
	    $c->stash->{error} = "Can't raid this town, as you have IP addresses in common with the mayor's party";
	    $c->forward( '/panel/refresh', [ 'messages' ]);
        return;
    }
	
    # If the mayor is an NPC or doesn't exist, check each party who's had a mayor here in the last few days
    #  They may have just reliquinshed the mayoralty, and left it for their co-op party to come
    #  claim it
    if (! $mayor || $mayor->is_npc) {
        my @mayor_history = $c->model('DBIC::Party_Mayor_History')->search(
           {
               town_id => $town->id,
               party_id => {'!=', $c->stash->{party}->id},
               'lost_mayoralty_day_rec.day_number' => {'>=', $c->stash->{today}->day_number - 3},
           },
           {
               join => 'lost_mayoralty_day_rec',
           }
        );
        
        foreach my $history (@mayor_history) {
            if ($c->stash->{party}->is_suspected_of_coop_with( $history->party ) ) {
        	    $c->stash->{error} = "Can't raid this town, as you have IP addresses in common with a recent mayor's party";
        	    $c->forward( '/panel/refresh', [ 'messages' ]);
                return;
            }
        }       
    }	

	$c->stash->{party}->dungeon_grid_id( $start_sector->id );
	$c->stash->{party}->update;

	$party_town->last_raid_start( DateTime->now() );
	$party_town->last_raid_end(undef);
	$party_town->increment_raids_today;
	$party_town->update;
	
    push @{$c->stash->{panel_callbacks}}, {
        name => 'setMinimapVisibility',
        data => 0,
    };
    
    if (! $mayor) {
        push @{$c->stash->{panel_messages}}, "This town doesn't have a mayor! You won't be able to conquer this town until one is appointed";
    }
    
    elsif (! $mayor->creature_group_id || ! $mayor->creature_group->dungeon_grid_id) {
        push @{$c->stash->{panel_messages}}, "The mayor of this town changed recently, and the mayor is not yet in the castle. You won't be able to conquer this " .
            "town until the mayor enters the castle";
    }
	
	$c->stash->{message_panel_size} = 'small'; 

	$c->forward( '/panel/refresh', [ 'messages', 'party_status', 'map', 'creatures' ] );
}

sub enter_sewer : Local {
	my ( $self, $c ) = @_;
	
	my $town = $c->model('DBIC::Town')->find( { land_id => $c->stash->{party_location}->id } );
	
	my $start_sector = $c->model('DBIC::Dungeon_Grid')->find(
		{
			'dungeon.land_id' => $town->land_id,
			'stairs_up'       => 1,
			'dungeon.type'    => 'sewer',
		},
		{
			join => { 'dungeon_room' => 'dungeon' },
		}
	);

	confess "Sewer not found for town " . $town->id unless $start_sector;	
	
	$c->stash->{party}->dungeon_grid_id( $start_sector->id );
	$c->stash->{party}->update;

	$c->stash->{message_panel_size} = 'small';
	
    push @{$c->stash->{panel_callbacks}}, {
        name => 'setMinimapVisibility',
        data => 0,
    };

	$c->forward( '/panel/refresh', [ 'messages', 'party_status', 'map', 'creatures' ] );	
}

sub become_mayor : Local {
	my ( $self, $c ) = @_;

	my $town = $c->model('DBIC::Town')->find(
		{
			pending_mayor => $c->stash->{party}->id,
			town_id       => $c->req->param('town_id'),
		}
	);

	croak "Not pending mayor of that town" unless $town;
	
	if (my $old_mayor = $town->mayor) {
	   # Hmm, they've submitted the "become mayor" dialog, but there's still a mayor.
	   #  This shouldn't happen. We'll clean up anyway (could have been some sort of transient error when ending the raid)
	   $old_mayor->was_killed($c->stash->{party});
	}
	
	if ($c->req->param('decline')) {
	   $town->decline_mayoralty();
	   $town->update;
	   $c->forward( '/panel/refresh', [ 'messages' ] );
	   return;   
	}

	my ($character) = grep { $_->id == $c->req->param('character_id') } $c->stash->{party}->characters_in_party;

	croak "Character not in party" unless $character;

	$character->mayor_of( $town->id );	
	$character->update;
	
	$character->apply_roles;
	$character->gain_mayoralty($town);
	
	$town->pending_mayor(undef);
	$town->pending_mayor_date(undef);
	$town->update;
	
	$town->add_to_history(
   		{
			day_id  => $c->stash->{today}->id,
           	message => "The towns people allow the triumphant party " . $c->stash->{party}->name . " to appoint a new mayor. They select "
           	    . $character->character_name . " for the job",
   		}
   	);	
	  	
	$c->model('DBIC::Party_Messages')->create(
		{
			message => "We deposed the mayor of " . $town->town_name . " and appointed " . $character->character_name . " to take over the mayoral duties there",
			alert_party => 0,
			party_id => $c->stash->{party}->id,
			day_id => $c->stash->{today}->id,
		}
	);

    $c->stash->{panel_messages} = [ $character->character_name . ' is now the mayor of ' . $town->town_name . '!' ];

	my $messages = $c->forward( '/quest/check_action', [ 'taken_over_town', $town ] );
	push @{ $c->stash->{panel_messages} }, $messages if $messages && @$messages;

	$c->forward( '/panel/refresh', [ 'messages', 'party', 'map' ] );
}

1;
