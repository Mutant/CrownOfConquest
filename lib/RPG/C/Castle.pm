package RPG::C::Castle;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Games::Dice::Advanced;
use Math::Round qw(round);
use Data::Dumper;

sub move_to : Local {
	my ( $self, $c ) = @_;

	$c->forward('/dungeon/move_to');
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
	
	foreach my $cg (@guards_in_room) {
		if ($c->session->{spotted}{$cg->id}) {
			push @seeking, $cg;				
		}
		else {
			push @patrolling, $cg;
		}
	}

	$c->forward( '/dungeon/move_creatures', [ $sector, \@patrolling, 75 ] );
	

	foreach my $cg (@seeking) {
		my @path = $dungeon->find_path_to_sector(
			$cg->dungeon_grid,
			{
				x => $sector->x,
				y => $sector->y,
			}
		);
		
		my $moves = Games::Dice::Advanced->roll('1d3');
		$moves = scalar @path if scalar @path < $moves;
		
		warn Dumper \@path;
		warn $moves;
		
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
		
		$cg->dungeon_grid_id($new_sector->id);
		$cg->update;
		
		last if $new_sector->id == $sector->id;
	}
	
	foreach my $cg (@patrolling) {
		$cg->discard_changes;
		my $distance = RPG::Map->get_distance_between_points(
			{
				x => $sector->x,
				y => $sector->y,
			},
			{
				x => $cg->dungeon_grid->x,
				y => $cg->dungeon_grid->y,
			}
		);
		
		if ($distance <= 3) {
			# See if the guards spot the party
			my $spot_chance = 15 * (4 - $distance);

			if ($spot_chance <= Games::Dice::Advanced->roll('1d100')) {
				$c->session->{spotted}{$cg->id} = 1;
				push @{$c->stash->{messages}}, "You were spotted by the guards!";
			}
		}
	}
}

sub successful_flee : Private {
	my ($self, $c, $castle) = @_;
	
	if (Games::Dice::Advanced->roll('1d100') <= $c->config->{castle_capture_chance}) {
		my $turns_lost = round $castle->town->prosperity / 4;
		$c->stash->{party}->turns($c->stash->{party}->turns - $turns_lost);
		$c->stash->{party}->dungeon_grid_id(undef);
		$c->stash->{party}->update;
		
		push @{$c->stash->{panel_messages}}, "You are captured and thrown in prison for $turns_lost turns!";
	}
}

1;
