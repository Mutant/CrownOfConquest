use strict;
use warnings;

package Test::RPG::C::Castle;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Dungeon_Room;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::CreatureGroup;
use Test::RPG::Builder::Character;

use RPG::C::Castle;

sub setup : Tests(setup) {
	my $self = shift;	

	$self->mock_dice;
}

sub shutdown : Tests(shutdown) {
	my $self = shift;	

	$self->unmock_dice;	
}

sub test_check_for_creature_move_party_spotted : Tests(1) {
	my $self = shift;
	
	# GIVEN
	$self->{roll_result} = 30;
	
	my $castle = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema});
	my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, top_left => {x=>1,y=>1}, bottom_right=>{x=>5,y=>5}, dungeon_id => $castle->id);
	my $town = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $castle->land_id);

	my @sectors = $room->sectors;
	
	$self->{mock_forward}{'/dungeon/move_creatures'} = sub {};

	my $party = Test::RPG::Builder::Party->build_party($self->{schema}, dungeon_grid_id => $sectors[0]->id);
	my $cg = Test::RPG::Builder::CreatureGroup->build_cg($self->{schema}, dungeon_grid_id => $sectors[2]->id);
	$self->{stash}{party} = $party;
		
	# WHEN
	RPG::C::Castle->check_for_creature_move($self->{c}, $sectors[0]);
	
	# THEN
	is($self->{session}{spotted}{$cg->id}, 1, "Party spotted");
}

sub test_check_for_creature_move_guards_seek_party : Tests(1) {
	my $self = shift;
	
	# GIVEN
	$self->{roll_result} = 3;
	
	my $castle = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema});
	my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, top_left => {x=>1,y=>1}, bottom_right=>{x=>5,y=>5}, dungeon_id => $castle->id);
	my $town = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $castle->land_id);
	
	$castle->populate_sector_paths();
	
	my @sectors = $room->sectors;
	
	$self->{mock_forward}{'/dungeon/move_creatures'} = sub {};

	my $party = Test::RPG::Builder::Party->build_party($self->{schema}, dungeon_grid_id => $sectors[0]->id);
	my $cg = Test::RPG::Builder::CreatureGroup->build_cg($self->{schema}, dungeon_grid_id => $sectors[9]->id);
	$self->{session}{spotted}{$cg->id} = 1;

	$self->{stash}{party} = $party;
		
	# WHEN
	RPG::C::Castle->check_for_creature_move($self->{c}, $sectors[0]);
	
	# THEN	
	$cg->discard_changes;
	is($cg->dungeon_grid_id, $sectors[1]->id, "Guards moved towards party");
}

sub test_check_for_creature_move_party_not_spotted_as_out_of_range : Tests(1) {
	my $self = shift;
	
	# GIVEN
	$self->{roll_result} = 30;
	
	my $castle = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema});
	my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, top_left => {x=>1,y=>1}, bottom_right=>{x=>5,y=>5}, dungeon_id => $castle->id);
	my $town = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $castle->land_id);
	my $party = Test::RPG::Builder::Party->build_party($self->{schema});
	
	$self->{stash}{party} = $party;	
	
	my @sectors = $room->sectors;
	
	$self->{mock_forward}{'/dungeon/move_creatures'} = sub {};

	my $party2 = Test::RPG::Builder::Party->build_party($self->{schema}, dungeon_grid_id => $sectors[0]->id);
	my $cg = Test::RPG::Builder::CreatureGroup->build_cg($self->{schema}, dungeon_grid_id => $sectors[24]->id);
		
	# WHEN
	RPG::C::Castle->check_for_creature_move($self->{c}, $sectors[0]);
	
	# THEN
	is($self->{session}{spotted}{$cg->id}, undef, "Party not spotted");
}

sub test_end_raid : Tests(1) {
	my $self = shift;
	
	# GIVEN
	my $castle = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema});
	my $town = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $castle->land_id);
	my $party = Test::RPG::Builder::Party->build_party($self->{schema});
	my $mayor = Test::RPG::Builder::Character->build_character($self->{schema});
	
	$mayor->mayor_of($town->id);
	$mayor->update;
	
	$town->pending_mayor($party->id);
	$town->update;
	
	$self->{stash}{party} = $party;	
	
	# WHEN
	RPG::C::Castle->end_raid($self->{c}, $castle);
	
	# THEN
	$mayor->discard_changes;
	is($mayor->mayor_of, undef, "Mayor is no longer mayor");	   
}

sub test_successful_flee : Tests(4) {
    my $self = shift;
	
	# GIVEN
	my $castle = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema});
	my $town = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $castle->land_id);
	my $party = Test::RPG::Builder::Party->build_party($self->{schema});
	my $mayor = Test::RPG::Builder::Character->build_character($self->{schema});
	
	$mayor->mayor_of($town->id);
	$mayor->update;
	
	$town->pending_mayor($party->id);
	$town->update;
	
	$self->{config}{castle_capture_chance} = 100;
	
	$self->{stash}{party} = $party;
	
	$self->{mock_forward}{'/dungeon/exit'} = sub {};
	$self->{mock_forward}{'end_raid'} = sub {};
	
	# WHEN
	RPG::C::Castle->successful_flee($self->{c}, $castle);
	
	# THEN
	$town->discard_changes;
	is($town->pending_mayor, undef, "Party no longer pending mayor");
	is($town->history->count, 1, "Message added to town history");
	
	$mayor->discard_changes;
	is($mayor->mayor_of, $town->id, "Mayor is still mayor");
	
	my $party_town = $self->{schema}->resultset('Party_Town')->find(
		{
			town_id  => $castle->town->id,
			party_id => $party->id,
		}
	);
	is($party_town->prestige, -10, "Prestige reduced");
	
}
