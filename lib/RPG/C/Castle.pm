package RPG::C::Castle;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Games::Dice::Advanced;
use Math::Round qw(round);
use Data::Dumper;

sub move_to : Local {
	my ( $self, $c ) = @_;
	
	my $turn_cost = $c->session->{castle_move_type} eq 'stealth' ? 4 : 1;

	$c->forward('/dungeon/move_to', [undef, $turn_cost]);
}

sub check_for_creature_move : Private {
	my ( $self, $c, $sector ) = @_;
	
	my $dungeon = $sector->dungeon_room->dungeon;

	my @guards_in_room = $c->model('DBIC::CreatureGroup')->search( 
		{ 'dungeon_room.dungeon_id' => $dungeon->id, }, 
		{ prefetch => {'dungeon_grid' => 'dungeon_room'}, }, 
	);
	
	my @patrolling;
	my @seeking;
	
	warn Dumper $c->session->{spotted};
	
	foreach my $cg (@guards_in_room) {
		if ($c->session->{spotted}{$cg->id}) {
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
	
		my $new_sector_coords = $path[$moves-1];
						
		my $new_sector = $c->model('DBIC::Dungeon_Grid')->find(
			{
				x => $new_sector_coords->{x},
				y => $new_sector_coords->{y},
				'dungeon_room.dungeon_id' => $dungeon->id,
			},
			{
				join => 'dungeon_room',
			}
		);
		
		warn "Guards seeking to " . $new_sector_coords->{x} . ',' . $new_sector_coords->{y};
		
		$cg->dungeon_grid_id($new_sector->id);
		$cg->update;
		
		last if $new_sector->id == $sector->id;
	}
	
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
		if ($distance <= 3) {
			# See if the guards spot the party
			my $base_chance = $c->session->{castle_move_type} eq 'stealth' ? 6 : 15;
			my $spot_chance = $base_chance * (4 - $distance);
			my $roll = Games::Dice::Advanced->roll('1d100');
			
			warn "Spot chance: $spot_chance, roll: $roll";

			if ($roll <= $spot_chance) {
				$c->session->{spotted}{$cg->id} = 1;
				push @{$c->stash->{messages}}, "You were spotted by the guards!" unless $spotted;
				$spotted = 1;
			}
		}
	}
}

sub successful_flee : Private {
	my ($self, $c, $castle) = @_;
	
	if (Games::Dice::Advanced->roll('1d100') <= $c->config->{castle_capture_chance}) {
		my $turns_lost = round $castle->town->prosperity / 3;
		push @{$c->stash->{panel_messages}}, "You are captured and thrown in prison for $turns_lost turns!";
				
		$c->forward('/dungeon/exit', [$turns_lost]);
	}
}

sub toggle_move_type : Local {
	my ($self, $c) = @_;
	
	$c->session->{castle_move_type} = $c->session->{castle_move_type} && $c->session->{castle_move_type} eq 'stealth' ? 'normal' : 'stealth';
	
	$c->forward( '/panel/refresh', [ 'messages' ] );
}

1;
