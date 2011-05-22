package RPG::C::Castle;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Games::Dice::Advanced;
use Math::Round qw(round);
use Data::Dumper;
use DateTime;

sub move_to : Local {
	my ( $self, $c ) = @_;

	my $turn_cost = $c->session->{castle_move_type} eq 'stealth' ? 4 : 1;

	$c->forward( '/dungeon/move_to', [ undef, $turn_cost ] );
}

sub check_for_creature_move : Private {
	my ( $self, $c, $sector ) = @_;

	my $dungeon = $sector->dungeon_room->dungeon;

	my @guards_in_room = $c->model('DBIC::CreatureGroup')->search(
		{ 'dungeon_room.dungeon_id' => $dungeon->id, },
		{ prefetch                  => { 'dungeon_grid' => 'dungeon_room' }, },
	);

	my @patrolling;
	my @seeking;

	foreach my $cg (@guards_in_room) {
		if ( $c->session->{spotted}{ $cg->id } ) {
			push @seeking, $cg;
		}
		else {
			next unless $sector->dungeon_room_id == $cg->dungeon_grid->dungeon_room_id;
			push @patrolling, $cg;
		}
	}

	$c->forward( '/dungeon/move_creatures', [ $sector, \@patrolling, 50, 2 ] );

	foreach my $cg (@seeking) {
		my $cg_sector = $cg->dungeon_grid;

		next if $cg_sector->id == $sector->id;

		my @path = $dungeon->find_path_to_sector(
			$cg_sector,
			{
				x => $sector->x,
				y => $sector->y,
			}
		);

		my $moves = Games::Dice::Advanced->roll('1d3');
		$moves = scalar @path if scalar @path < $moves;

		my $new_sector_coords = $path[ $moves - 1 ];

		my $new_sector = $c->model('DBIC::Dungeon_Grid')->find(
			{
				x                         => $new_sector_coords->{x},
				y                         => $new_sector_coords->{y},
				'dungeon_room.dungeon_id' => $dungeon->id,
			},
			{
				join => 'dungeon_room',
			}
		);

		$c->log->debug( "Guards seeking to " . $new_sector_coords->{x} . ',' . $new_sector_coords->{y} );

		$cg->dungeon_grid_id( $new_sector->id );
		$cg->update;

		last if $new_sector->id == $sector->id;
	}

	my $party_town = $c->model('DBIC::Party_Town')->find_or_create(
		{
			town_id  => $dungeon->town->id,
			party_id => $c->stash->{party}->id,
		}
	);

	foreach my $cg (@patrolling) {
		$cg->discard_changes;

		my $guard_sector = $cg->dungeon_grid;

		next unless $sector->dungeon_room_id == $guard_sector->dungeon_room_id;

		my $distance = RPG::Map->get_distance_between_points(
			{
				x => $sector->x,
				y => $sector->y,
			},
			{
				x => $guard_sector->x,
				y => $guard_sector->y,
			}
		);

		my $spotted = 0;
		if ( $distance <= 3 ) {

			# See if the guards spot the party
			my $base_chance = $c->session->{castle_move_type} eq 'stealth' ? 6 : 15;
			my $spot_chance = $base_chance * ( 4 - $distance );
			my $roll = Games::Dice::Advanced->roll('1d100');

			$c->log->debug("Spot chance: $spot_chance, roll: $roll");

			if ( $roll <= $spot_chance ) {
				$c->session->{spotted}{ $cg->id } = 1;
				push @{ $c->stash->{messages} }, "You were spotted by the guards!" unless $spotted;

				$party_town->decrease_prestige(2);
				$spotted = 1;
			}
		}
	}

	$party_town->update;
}

sub successful_flee : Private {
	my ( $self, $c, $castle ) = @_;

	if ( Games::Dice::Advanced->roll('1d100') <= $c->config->{castle_capture_chance} ) {
		my $turns_dice = round $castle->town->prosperity / 4;
		$turns_dice ||= 1;
		my $turns_lost = 20 + Games::Dice::Advanced->roll( '1d' . $turns_dice );
		push @{ $c->stash->{panel_messages} }, "While fleeing, you are captured and thrown into the town's jail for $turns_lost turns!";

		my $party_town = $c->model('DBIC::Party_Town')->find_or_create(
			{
				town_id  => $castle->town->id,
				party_id => $c->stash->{party}->id,
			}
		);
		$party_town->decrease_prestige(10);
		$party_town->update;
		$c->stash->{captured} = $turns_lost;
		
		my $town = $castle->town;
		
		# Lose pending mayor
		$town->pending_mayor(undef) if $town->pending_mayor == $c->stash->{party}->id;

		$c->forward( 'end_raid', [$castle] );

		$c->forward( '/dungeon/exit', [$turns_lost] );
	}
}

sub toggle_move_type : Local {
	my ( $self, $c ) = @_;

	$c->session->{castle_move_type} = $c->session->{castle_move_type} && $c->session->{castle_move_type} eq 'stealth' ? 'normal' : 'stealth';

	$c->forward( '/panel/refresh', ['messages'] );
}

sub exit : Private {
	my ( $self, $c, $turns, $castle ) = @_;

	$c->forward( 'end_raid', [$castle] );

	$c->forward( '/dungeon/exit', [$turns] );
}

sub end_raid : Private {
	my ( $self, $c, $castle ) = @_;
	
	my $town = $castle->town;

	my $party_town = $c->model('DBIC::Party_Town')->find_or_create(
		{
			town_id  => $town->id,
			party_id => $c->stash->{party}->id,
		}
	);

	my @battles = $c->model('DBIC::Combat_Log')->get_party_logs_since_date(
		$c->stash->{party},
		$party_town->last_raid_start,
	);
	
	# Check to see if party is now pending mayor of the town. i.e. the mayor was killed
	my $mayor_killed = 0;
	if ($town->pending_mayor == $c->stash->{party}->id and my $mayor = $town->mayor) {
		$mayor_killed = 1;
		
        $mayor->lose_mayoralty;
        
    	my $today = $c->stash->{today};
		
    	# Leave a message for the mayor's party
    	if ($mayor->party_id) {
    	    my $party = $mayor->party;
    		$party->add_to_messages(
    			{
    				message => $mayor->character_name . " was killed by the party " . $c->stash->{party}->name . " and is no longer mayor of " 
    				. $town->town_name . ". " . ucfirst $mayor->pronoun('posessive-subjective') . " body has been interred in the town cemetery, and "
    				. $mayor->pronoun('posessive') . " may be resurrected there.",
    				alert_party => 1,
    				party_id => $mayor->party_id,
    				day_id => $today->id,
    			}
    		);		
    	}
    	
    	my $town_history_msg = "Mayor " . $mayor->character_name . " was dishonoured in combat by " . $c->stash->{party}->name . ". " . 
    	   ucfirst $mayor->pronoun('subjective') . " has been thrown out of office in disgrace.";
               		
        if ($town->peasant_state eq 'revolt') {
        	$town_history_msg .= " The peasants give up their revolt."; 
        }
        
        # Cancel election, if there's one in progress
        my $election = $town->current_election;
        if ($election) {
        	$election->status("Cancelled");
        	$election->update;
        	$town_history_msg .= " The upcoming election is cancelled.";
        }
               		
    	$town->add_to_history(
       		{
    			day_id  => $today->id,
               	message => $town_history_msg,
       		}
       	);        

	}

	my $killed_count;
	foreach my $battle (@battles) {
		$party_town->decrease_prestige(7);
		
		my $enemy_num = $battle->enemy_num_of( $c->stash->{party} );
		my $stats     = $battle->opponent_stats;

		$killed_count += $stats->{$enemy_num}{deaths};
		$c->log->debug( $stats->{$enemy_num}{deaths} . " guards killed in battle, reducing prosperity" );
	}

	if ( ! $mayor_killed && ($c->session->{spotted} || @battles) ) {
		my $news = $c->forward(
			'RPG::V::TT',
			[
				{
					template => 'town/raid_news.html',
					params   => {
						battle_count => scalar @battles,
						killed_count => $killed_count,
						captured     => $c->stash->{captured},
						party => $c->stash->{party},
						town => $town,
					},
					return_output => 1,
				}
			]
		);

		$c->model('DBIC::Town_History')->create(
			{
				town_id => $town->id,
				day_id  => $c->stash->{today}->id,
				message => $news,
			}
		);
	}

	$party_town->decrease_prestige( $killed_count * 10 );
	$party_town->increase_guards_killed($killed_count);
	$party_town->last_raid_end( DateTime->now() );
	$party_town->update;
}

1;
