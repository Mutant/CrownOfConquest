package RPG::C::Castle;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Games::Dice::Advanced;
use Math::Round qw(round);
use Data::Dumper;
use DateTime;
use List::Util qw(shuffle);

sub move_to : Local {
	my ( $self, $c ) = @_;

	my $turn_cost = ($c->session->{castle_move_type} // '') eq 'stealth' ? 4 : $c->config->{cost_of_moving_through_dungeons};
	
	my $sector = $c->model('DBIC::Dungeon_Grid')->find( 
	   { 
	       'dungeon_grid_id' => $c->stash->{party}->dungeon_grid_id, 
	   }, 
	   { 
	       prefetch => {'dungeon_room' => 'dungeon'}, 
	   } 
    );
	
	my $town = $sector->dungeon_room->dungeon->town;

	if ($town->trap_level > 0) {
	   # Check to see if a trap is triggered
	   my $prosp_adjustment = 20 - (round $town->prosperity / 5);
	   
	   my $chance = $town->trap_level * 3 + $prosp_adjustment;
	   $chance = 30 if $chance > 30;
	   
	   if (Games::Dice::Advanced->roll('1d100') <= $chance) {
	       # Check if party sees trap
	       my $avg_div = $c->stash->{party}->average_stat('divinity') // 0;
	       my $bonus = $c->stash->{party}->skill_aggregate('Awareness', 'chest_trap') // 0;
	       
	       my $trap_quot = $chance + Games::Dice::Advanced->roll('1d50');
	       my $party_quot = $avg_div + $bonus + Games::Dice::Advanced->roll('1d50');

	       if ($trap_quot > $party_quot) {
	           # Trap triggered
	           my @types = qw/Curse Hypnotise Mute Detonate/;
	           
	           my $trap = ( shuffle @types )[0];
	           my $level = round $town->trap_level / 2; 
	           
	           $c->forward('/dungeon/execute_trap', [ $trap, $level ]);
	       }
	       else {
	           # Party avoid trap
	           push @{$c->stash->{messages}}, "There was trap here, but we found and disarmed it!";
	       }	          
	   }   
	}
	
	# If the party is pending mayor, they must have killed the mayor during this raid, so set an increase
	#  search range when looking for creatures
	if (defined $town->pending_mayor && $town->pending_mayor == $c->stash->{party}->id) {
	    $c->stash->{creature_search_range} = 10;
	}

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
		my $message = "While fleeing, you are captured and thrown into the town's jail for $turns_lost turns!";
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
		if ($town->pending_mayor == $c->stash->{party}->id) {
            $town->decline_mayoralty;
            $message .= " You lose your chance to claim the mayoralty after defeating the mayor. The town is now under marshal law";
		}
		$town->update;
		
		push @{ $c->stash->{panel_messages} }, $message;

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
	
	my $raid = $c->model('DBIC::Town_Raid')->find(
		{
			town_id  => $town->id,
			party_id => $c->stash->{party}->id,
			date_ended => undef,
		},	
	);

	my @battles = $c->model('DBIC::Combat_Log')->get_party_logs_since_date(
		$c->stash->{party},
		$raid->date_started,
	);
	
	# Check to see if party is now pending mayor of the town. i.e. the mayor was killed
	my $mayor_killed = 0;
	if ($town->pending_mayor == $c->stash->{party}->id and my $mayor = $town->mayor) {
		$mayor_killed = 1;
		
        $mayor->was_killed($c->stash->{party});
	}

	my $killed_count;
	foreach my $battle (@battles) {		
		my $enemy_num = $battle->enemy_num_of( $c->stash->{party} );
		my $stats     = $battle->opponent_stats;

		$killed_count += $stats->{$enemy_num}{deaths};		
	}
	
	$c->log->debug( "$killed_count guards killed in battle, reducing prestige" );

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
	$party_town->update;
	
	$raid->date_ended(DateTime->now());
	$raid->guards_killed($killed_count);
	$raid->defeated_mayor($mayor_killed);
	$raid->detected(($c->session->{spotted} || scalar @battles) ? 1 : 0);
	$raid->battle_count(scalar @battles);
	$raid->update;
	
	undef $c->session->{spotted};
}

1;
