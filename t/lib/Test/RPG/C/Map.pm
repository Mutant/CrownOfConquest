use strict;
use warnings;

package Test::RPG::C::Map;

__PACKAGE__->runtests unless caller();

use base qw(Test::RPG::DB);

use Test::MockObject;
use Test::More;
use Test::Exception;

use RPG::C::Map;

use Data::Dumper;

use Test::RPG::Builder::Land;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Day;
use Test::RPG::Builder::Road;

sub setup : Tests(setup) {
	my $self = shift;

	Test::RPG::Builder::Day->build_day( $self->{schema} );
}

sub test_move_to_invalid_town_entrance : Tests(1) {
	my $self = shift;

	# GIVEN
	my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
	my $town =
	  Test::RPG::Builder::Town->build_town( $self->{schema},
		land_id => $land[0]->id );

	my $party = Test::RPG::Builder::Party->build_party(
		$self->{schema},
		character_count => 2,
		land_id         => $land[1]->id
	);

	$self->{params}{land_id} = $land[0]->id;

	$self->{stash}{party} = $party;

	# WHEN / THEN
	throws_ok(
		sub { RPG::C::Map->move_to( $self->{c} ) },
		qr/Invalid town entrance/,
		"Illegal entering of town not permitted"
	);
}

sub test_move_to_successful_move : Tests(4) {
	my $self = shift;

	# GIVEN
	my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );

	my $party = Test::RPG::Builder::Party->build_party(
		$self->{schema},
		character_count => 2,
		land_id         => $land[1]->id
	);

	$self->{params}{land_id} = $land[0]->id;

	$self->{stash}{party}          = $party;
	$self->{stash}{party_location} = $party->location;

	$self->{mock_forward}{'/combat/check_for_attack'} = sub { };
	$self->{mock_forward}{'/panel/refresh'}           = sub { };

	# WHEN
	RPG::C::Map->move_to( $self->{c} );

	# THEN
	$party->discard_changes;
	is( $party->turns,   95,           "Turns reduced" );
	is( $party->land_id, $land[0]->id, "Moved to correct sector" );

	$land[0]->discard_changes;
	is( $land[0]->creature_threat, 9, "Creature threat reduced" );
	is( $self->{stash}{party_location}->id,
		$land[0]->id, "Stash party location updated correctly" );
}

sub test_move_to_successful_town_entrance : Tests(4) {
	my $self = shift;

	# GIVEN
	my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
	my $town =
	  Test::RPG::Builder::Town->build_town( $self->{schema},
		land_id => $land[0]->id );

	my $party = Test::RPG::Builder::Party->build_party(
		$self->{schema},
		character_count => 2,
		land_id         => $land[1]->id
	);

	$self->{params}{land_id} = $land[0]->id;

	$self->{stash}{party}          = $party;
	$self->{stash}{party_location} = $party->location;
	$self->{stash}{entered_town}   = 1;

	$self->{mock_forward}{'/combat/check_for_attack'} = sub { };
	$self->{mock_forward}{'/panel/refresh'}           = sub { };

	# WHEN
	RPG::C::Map->move_to( $self->{c} );

	# THEN
	$party->discard_changes;
	is( $party->turns,   95,           "Turns reduced" );
	is( $party->land_id, $land[0]->id, "Moved to correct sector" );

	$land[0]->discard_changes;
	is( $land[0]->creature_threat, 9, "Creature threat reduced" );
	is( $self->{stash}{party_location}->id,
		$land[0]->id, "Stash party location updated correctly" );
}

sub test_known_dungeons : Tests(7) {
	my $self = shift;

	# GIVEN
	my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );

	my $dungeon1 = $self->{schema}->resultset('Dungeon')->create(
		{
			level   => 1,
			land_id => $land[5]->id,
		}
	);

	my $dungeon2 = $self->{schema}->resultset('Dungeon')->create(
		{
			level   => 1,
			land_id => $land[8]->id,
		}
	);

	my $party = Test::RPG::Builder::Party->build_party(
		$self->{schema},
		character_count => 2,
		character_level => 10
	);

	$self->{stash}{party} = $party;

	# All but 1 sector mapped
	my @mapped_sectors;
	for my $id ( 0 .. 7 ) {
		push @mapped_sectors,
		  $self->{schema}->resultset('Mapped_Sectors')->create(
			{
				land_id  => $land[$id]->id,
				party_id => $party->id,
			}
		  );
	}
	$mapped_sectors[2]->phantom_dungeon(2);
	$mapped_sectors[2]->update;

	# WHEN
	RPG::C::Map->known_dungeons( $self->{c} );

	# THEN
	my @known_dungeons = @{ $self->template_params->{known_dungeons} };
	is( scalar @known_dungeons, 2, "2 known dungeons" );

	is( $known_dungeons[0]->{level}, 1, "First known dungeon level returned" );
	is( $known_dungeons[0]->{x}, $land[5]->x,
		"First known dungeon x returned" );
	is( $known_dungeons[0]->{y}, $land[5]->y,
		"First known dungeon y returned" );

	is( $known_dungeons[1]->{level}, 2, "First known dungeon level returned" );
	is( $known_dungeons[1]->{x}, $land[2]->x,
		"First known dungeon x returned" );
	is( $known_dungeons[1]->{y}, $land[2]->y,
		"First known dungeon y returned" );

}

sub test_generated_grid_has_correct_movement_costs : Tests(2) {
	my $self = shift;

	# GIVEN
	my @land  = Test::RPG::Builder::Land->build_land( $self->{schema} );
	my $road1 = Test::RPG::Builder::Road->build_road(
		$self->{schema},
		land_id  => $land[4]->id,
		position => 'top left'
	);
	my $road2 = Test::RPG::Builder::Road->build_road(
		$self->{schema},
		land_id  => $land[0]->id,
		position => 'bottom right'
	);
	
	my $party = Test::MockObject->new();
	$party->set_always('id', 1);
	$party->set_always('movement_factor', 1);
	$party->set_always('location', $land[4]);
	
	$self->{stash}{party} = $party;
	$self->{stash}{party_location} = $land[4];
	
	# WHEN
	my $result = RPG::C::Map->generate_grid($self->{c}, 3, 3, 2, 2, 1);
	
	# THEN
	my $grid = $result->{grid};
	is($grid->[1][1]->{party_movement_factor}, 2, "Sector 1,1 movement factor correct");
	is($grid->[1][2]->{party_movement_factor}, 4, "Sector 1,2 movement factor correct");

}

1;
