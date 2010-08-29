use strict;
use warnings;

package Test::RPG::NewDay::CastleGuardGenerator;

use base qw(Test::RPG::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Dungeon_Room;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::CreatureType;
use Test::RPG::Builder::Character;
use Test::RPG::Builder::CreatureGroup;

sub setup : Test(setup => 2) {
    my $self = shift;

	use_ok 'RPG::NewDay::Role::CastleGuardGenerator';
	use_ok 'RPG::NewDay::Action::Castles';

    $self->setup_context;
    
}

sub shutdown : Test(shutdown) {
	my $self = shift;
}

sub test_generate_guards_basic : Tests(3) {
	my $self = shift;
	
	# GIVEN
	my $castle = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema}, type => 'castle',);
	my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, top_left => {x=>1,y=>1}, bottom_right=>{x=>5,y=>5}, dungeon_id => $castle->id);
	my $room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, top_left => {x=>6,y=>6}, bottom_right=>{x=>10,y=>10}, dungeon_id => $castle->id);
	my $town = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $castle->land_id, gold => 100, prosperity => 10);
		
	my $type1 = Test::RPG::Builder::CreatureType->build_creature_type($self->{schema}, creature_level => 6, category_name => 'Guards', hire_cost => 0);
	my $type2 = Test::RPG::Builder::CreatureType->build_creature_type($self->{schema}, creature_level => 10, category_name => 'Guards', hire_cost => 0);
	
	my $action = RPG::NewDay::Action::Castles->new( context => $self->{mock_context} );
	
	# WHEN
	$action->generate_guards($castle);
	
	# THEN
	my @cgs = $self->{schema}->resultset('CreatureGroup')->search();
	cmp_ok(scalar @cgs, '>=', 1, "At least one creature group generated");
	
	my $count = 0;
	my $level_aggr;
	foreach my $cg (@cgs) {
		foreach my $cret ($cg->creatures) {
			$level_aggr+=$cret->type->level;
			$count++;
		}			
	}
	
	is($count, 11, "11 creatures generated");
	is($level_aggr, 66, "Correct aggregate of levels");
}

sub test_generate_guards_high_prosperity : Tests(4) {
	my $self = shift;
	
	# GIVEN
	my $castle = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema});
	my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, top_left => {x=>1,y=>1}, bottom_right=>{x=>5,y=>5}, dungeon_id => $castle->id);
	my $room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, top_left => {x=>6,y=>6}, bottom_right=>{x=>10,y=>10}, dungeon_id => $castle->id);
	my $town = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $castle->land_id, gold => 100, prosperity => 50);
		
	my $type1 = Test::RPG::Builder::CreatureType->build_creature_type($self->{schema}, creature_level => 6, category_name => 'Guards', hire_cost => 0);
	my $type2 = Test::RPG::Builder::CreatureType->build_creature_type($self->{schema}, creature_level => 10, category_name => 'Guards', hire_cost => 0);
	
	my $action = RPG::NewDay::Action::Castles->new( context => $self->{mock_context} );
	
	# WHEN
	$action->generate_guards($castle);
	
	# THEN
	my @cgs = $self->{schema}->resultset('CreatureGroup')->search();
	cmp_ok(scalar @cgs, '>=', 1, "At least one creature group generated");
	
	my $level_aggr;
	my %cret_types;
	foreach my $cg (@cgs) {
		foreach my $cret ($cg->creatures) {
			$level_aggr+=$cret->type->level;
			$cret_types{$cret->type->id} = 1;
		}			
	}
	
	cmp_ok($level_aggr, '>=', 340, "Level aggregate above bound");
	cmp_ok($level_aggr, '<=', 355, "Level aggregate below bound");
	is(scalar keys %cret_types, 2, "Both creature types used");  
}

sub test_generate_guards_pays_for_guards_correct : Tests(3) {
	my $self = shift;
	
	# GIVEN
	my $castle = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema});
	my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, top_left => {x=>1,y=>1}, bottom_right=>{x=>5,y=>5}, dungeon_id => $castle->id);
	my $room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, top_left => {x=>6,y=>6}, bottom_right=>{x=>10,y=>10}, dungeon_id => $castle->id);
	my $town = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $castle->land_id, gold => 100, prosperity => 10);
		
	my $type1 = Test::RPG::Builder::CreatureType->build_creature_type($self->{schema}, creature_level => 5, category_name => 'Guards', hire_cost => 10);
	
	my $action = RPG::NewDay::Action::Castles->new( context => $self->{mock_context} );
	
	# WHEN
	$action->generate_guards($castle);	
	
	# THEN
	my @cgs = $self->{schema}->resultset('CreatureGroup')->search();
	cmp_ok(scalar @cgs, '>=', 1, "At least one creature group generated");
	
	my $level_aggr;
	my $count;
	foreach my $cg (@cgs) {
		foreach my $cret ($cg->creatures) {
			$level_aggr+=$cret->type->level;
			$count++;
		}			
	}
	
	is($count, 10, "Only 10 guards created");
	$town->discard_changes;
	is($town->gold, 0, "Spent all gold");
}

sub test_generate_guards_changes_as_per_requests : Tests(2) {
	my $self = shift;
	
	# GIVEN
	my $castle = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema});
	my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, top_left => {x=>1,y=>1}, bottom_right=>{x=>5,y=>5}, dungeon_id => $castle->id);
	my $room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, top_left => {x=>6,y=>6}, bottom_right=>{x=>10,y=>10}, dungeon_id => $castle->id);
	my $town = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $castle->land_id, gold => 100, prosperity => 10);
		
	my $type1 = Test::RPG::Builder::CreatureType->build_creature_type($self->{schema}, creature_level => 5, category_name => 'Guards', hire_cost => 0);
		
	my $character = Test::RPG::Builder::Character->build_character($self->{schema}, party_id => 1);
	$character->mayor_of($town->id);
	$character->update;
	
	my $hire = $self->{schema}->resultset('Town_Guards')->create(
		{
			town_id => $town->id,
			creature_type_id => $type1->id,
			amount => 10,
		}
	);
	
	my $action = RPG::NewDay::Action::Castles->new( context => $self->{mock_context} );	
	
	# WHEN
	$action->generate_guards($castle);	
	
	# THEN
	my @cgs = $self->{schema}->resultset('CreatureGroup')->search();
	is(scalar @cgs, 2, "Correct number of cgs generated");
	
	my $count;
	foreach my $cg (@cgs) {
		foreach my $cret ($cg->creatures) {
			$count++;
		}			
	}
	
	is($count, 10, "Only 10 guards created");	
}

sub test_generate_guards_changes_with_existing : Tests(3) {
	my $self = shift;
	
	# GIVEN
	my $castle = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema});
	my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, top_left => {x=>1,y=>1}, bottom_right=>{x=>5,y=>5}, dungeon_id => $castle->id);
	my $room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, top_left => {x=>6,y=>6}, bottom_right=>{x=>10,y=>10}, dungeon_id => $castle->id);
	my $town = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $castle->land_id, gold => 100, prosperity => 10);
		
	my $type1 = Test::RPG::Builder::CreatureType->build_creature_type($self->{schema}, creature_level => 5, category_name => 'Guards', hire_cost => 10);
	
	my @sectors = $room->sectors;	

	Test::RPG::Builder::CreatureGroup->build_cg(
		$self->{schema},
		type_id => $type1->id,
		dungeon_grid_id => $sectors[0]->id,
		creature_count => 20,
	);
		
	my $character = Test::RPG::Builder::Character->build_character($self->{schema}, party_id => 1);
	$character->mayor_of($town->id);
	$character->update;
	
	my $hire = $self->{schema}->resultset('Town_Guards')->create(
		{
			town_id => $town->id,
			creature_type_id => $type1->id,
			amount => 10,
		}
	);
	
	my $action = RPG::NewDay::Action::Castles->new( context => $self->{mock_context} );	
	
	# WHEN
	$action->generate_guards($castle);	
	
	# THEN
	my @cgs = $self->{schema}->resultset('CreatureGroup')->search();
	cmp_ok(scalar @cgs, '>=', 1, "At least one creature group generated");
	
	my $count;
	foreach my $cg (@cgs) {
		foreach my $cret ($cg->creatures) {
			$count++;
		}			
	}
	
	is($count, 10, "Only 10 guards created");
	$town->discard_changes;
	is($town->gold, 0, "All gold spent");
}

sub test_generate_guards_mayors_group : Tests(4) {
	my $self = shift;
	
	# GIVEN
	my $castle = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema});
	my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, top_left => {x=>1,y=>1}, bottom_right=>{x=>5,y=>5}, dungeon_id => $castle->id);
	my $room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, top_left => {x=>6,y=>6}, bottom_right=>{x=>10,y=>10}, dungeon_id => $castle->id);
	my $town = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $castle->land_id, gold => 100, prosperity => 10);
		
	my $type1 = Test::RPG::Builder::CreatureType->build_creature_type($self->{schema}, creature_level => 6, category_name => 'Guards', hire_cost => 0);
	my $type2 = Test::RPG::Builder::CreatureType->build_creature_type($self->{schema}, creature_level => 10, category_name => 'Guards', hire_cost => 0);
	
	my $mayor = Test::RPG::Builder::Character->build_character($self->{schema});
	$mayor->mayor_of($town->id);
	$mayor->update;
	
	my $action = RPG::NewDay::Action::Castles->new( context => $self->{mock_context} );
	
	# WHEN
	$action->generate_guards($castle);
	
	# THEN
	my @cgs = $self->{schema}->resultset('CreatureGroup')->search();
	cmp_ok(scalar @cgs, '>=', 1, "At least one creature group generated");
	
	my $count = 0;
	my $level_aggr;
	foreach my $cg (@cgs) {
		foreach my $cret ($cg->creatures) {
			$level_aggr+=$cret->type->level;
			$count++;
		}			
	}
	
	is($count, 11, "11 creatures generated");
	is($level_aggr, 66, "Correct aggregate of levels");
	
	$mayor->discard_changes;
	is(defined $mayor->creature_group_id, 1, "Mayor in a creature group");
}
1;
