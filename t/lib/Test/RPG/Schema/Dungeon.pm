package Test::RPG::Schema::Dungeon;

use strict;
use warnings;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;
use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Dungeon_Room;
use Test::RPG::Builder::Quest::Find_Dungeon_Item;
use Test::RPG::Builder::Quest::Find_Jewel;
use Test::RPG::Builder::Day;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::CreatureType;
use Test::RPG::Builder::CreatureGroup;

use Data::Dumper;

sub startup : Test(startup => 1) {
	my $self = shift;
		
	use_ok 'RPG::Schema::Dungeon';
}

sub test_party_can_enter_instance : Test(3) {
    my $self = shift;
    
    # GIVEN
    my $mock_party = Test::MockObject->new();
    my $mock_dungeon = Test::MockObject->new();
    $mock_dungeon->set_isa('RPG::Schema::Dungeon');
    
    $self->{config}{dungeon_entrance_level_step} = 5;
    
    my %tests = (
        low_level_party_allowed_to_enter_level_1_dungeon => {
            party_level => 1,
            dungeon_level => 1,
            expected_result => 1,
        },
        low_level_party_not_allowed_to_enter_level_2_dungeon => {
            party_level => 4,
            dungeon_level => 2,
            expected_result => 0,
        },
        level_5_party_allowed_to_enter_level_2_dungeon => {
            party_level => 5,
            dungeon_level => 2,
            expected_result => 1,
        },
    );
    
    # WHEN
    my %results;
    while (my ($test_name, $test_data) = each %tests) {        
        $mock_party->set_always('level',$test_data->{party_level});
        $mock_dungeon->set_always('level',$test_data->{dungeon_level});    
        $results{$test_name} = RPG::Schema::Dungeon::party_can_enter($mock_dungeon, $mock_party);
    }
    
    # THEN
    while (my ($test_name, $test_data) = each %tests) {
        is($results{$test_name}, $tests{$test_name}->{expected_result}, "Got expected result for: $test_name");
    }
}

sub test_party_can_enter_class : Test(1) {
    my $self = shift;
    
    # GIVEN
    my $mock_party = Test::MockObject->new();
    $mock_party->set_always('level',10);
    
    $self->{config}{dungeon_entrance_level_step} = 5;
    
    # WHEN
    my $result = RPG::Schema::Dungeon->party_can_enter(4, $mock_party);
    
    # THEN
    is($result, 0, "Successfully called party_can_enter as class method");
}

sub test_find_path_to_sector_1 : Test(5) {
	my $self = shift;
	
	# GIVEN
	my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema});
	my $dungeon_room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room(
		$self->{schema}, 
		dungeon_id => $dungeon->id,
		top_left => {x => 1, y => 1},
		bottom_right => {x => 5, y => 5},		
	);
	$dungeon->populate_sector_paths;
	
	my ($sector) = grep { $_->x == 2 && $_->y == 1 } $dungeon_room->sectors; 
		
	# WHEN
	my @path = $dungeon->find_path_to_sector(
		$sector,
		{
			x=>4,
			y=>5,
		}
	);
	
	# THEN
	is(scalar @path, 4, "4 steps in path");
	is_deeply($path[0], {x=>3,y=>2}, "First step correct");
	is_deeply($path[1], {x=>4,y=>3}, "Second step correct");
	is_deeply($path[2], {x=>4,y=>4}, "Third step correct");
	is_deeply($path[3], {x=>4,y=>5}, "Forth step correct");
}

sub test_find_path_to_sector_2 : Test(5) {
	my $self = shift;
	
	# GIVEN
	my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema});
	my $dungeon_room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room(
		$self->{schema}, 
		dungeon_id => $dungeon->id,
		top_left => {x => 11, y => 11},
		bottom_right => {x => 15, y => 15},		
	);
	$dungeon->populate_sector_paths;
	
	my ($sector) = grep { $_->x == 13 && $_->y == 11 } $dungeon_room->sectors;
	
	# WHEN
	my @path = $dungeon->find_path_to_sector(
		$sector,
		{
			x=>15,
			y=>15,
		}
	);
	
	# THEN
	is(scalar @path, 4, "4 steps in path");
	is_deeply($path[0], {x=>14,y=>12}, "First step correct");
	is_deeply($path[1], {x=>15,y=>13}, "Second step correct");
	is_deeply($path[2], {x=>15,y=>14}, "Third step correct");
	is_deeply($path[3], {x=>15,y=>15}, "Forth step correct");
}

sub test_delete : Tests(2) {
	my $self = shift;
	
	# GIVEN
	my $quest = Test::RPG::Builder::Quest::Find_Dungeon_Item->build_quest($self->{schema});
	my $quest2 = Test::RPG::Builder::Quest::Find_Jewel->build_quest($self->{schema});
	my $dungeon = $quest->dungeon;
	
	# WHEN
	$dungeon->delete;
	
	# THEN
	$quest->discard_changes;
	is($quest->in_storage, 0, "Quest deleted when dungeon deleted");
		
	$quest2->discard_changes;
	is($quest2->in_storage, 1, "Non-dungeon quest not deleted");	
}

sub test_delete_inprogress_quest : Tests(2) {
	my $self = shift;
	
	# GIVEN
	my $quest = Test::RPG::Builder::Quest::Find_Dungeon_Item->build_quest($self->{schema});
	my $party = Test::RPG::Builder::Party->build_party($self->{schema});
	my $day = Test::RPG::Builder::Day->build_day($self->{schema});
	
	$quest->party_id($party->id);
	$quest->status('In Progress');
	$quest->update;
	
	my $dungeon = $quest->dungeon;
	
	# WHEN
	$dungeon->delete;
	
	# THEN
	$quest->discard_changes;
	is($quest->in_storage, 0, "Quest deleted when dungeon deleted");
		
	my $message = $self->{schema}->resultset('Party_Messages')->find(
		{
			party_id => $party->id,
		}
	);
	
	is(defined $message, 1, "message added for party"); 
}

sub test_find_sectors_not_near_stairs : Tests(41) {
    my $self = shift;
    
    # GIVEN
	my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema});
	my $dungeon_room1 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room(
		$self->{schema}, 
		dungeon_id => $dungeon->id,
		top_left => {x => 1, y => 1},
		bottom_right => {x => 10, y => 10},		
	);
	my $dungeon_room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room(
		$self->{schema}, 
		dungeon_id => $dungeon->id,
		top_left => {x => 11, y => 1},
		bottom_right => {x => 15, y => 10},		
	);
	
	foreach my $sector ($dungeon_room1->sectors) {
	   if ($sector->x == 6 and $sector->y == 5) {
	       $sector->stairs_up(1);
	       $sector->update;   
	   }   
	}
	
	# WHEN
	my $sector_rs = $dungeon->find_sectors_not_near_stairs(1);
	
	# THEN
	is($sector_rs->count, 40, "Correct number of sectors returned");
	foreach my $sector ($sector_rs->all) {
	   cmp_ok($sector->x, '>=', 12, "Sector " . $sector->x . ", " . $sector->y . " in correct range");
	}
}

sub test_adding_creatures_basic : Tests(3) {
    my $self = shift;
    
    # GIVEN
	my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema});
	my $dungeon_room1 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room(
		$self->{schema}, 
		dungeon_id => $dungeon->id,
		top_left => {x => 1, y => 1},
		bottom_right => {x => 10, y => 10},		
	);
	my $dungeon_room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room(
		$self->{schema}, 
		dungeon_id => $dungeon->id,
		top_left => {x => 11, y => 1},
		bottom_right => {x => 15, y => 10},		
	);
	
	my $type1 = Test::RPG::Builder::CreatureType->build_creature_type($self->{schema});
	
	# WHEN
	$dungeon->add_or_remove_creatures(
        {
            type => $type1,
            amount => 3,
        }
    );
    
    # THEN
    my @cgs = $self->{schema}->resultset('CreatureGroup')->search(
        {
            'dungeon_room.dungeon_id' => $dungeon->id,
        },
        {
            join => { 'dungeon_grid' => 'dungeon_room' },
        } 
    );
    is(scalar @cgs, 1, "1 cg created");
    
    is($cgs[0]->creatures->count, 3, "CG has 3 creatures");
    
    is(grep ({ $_->creature_type_id == $type1->id } $cgs[0]->creatures), 3, "All CGs are of correct type");
}

sub test_adding_creatures_existing_cgs : Tests(3) {
    my $self = shift;
    
    # GIVEN
	my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema});
	my $dungeon_room1 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room(
		$self->{schema}, 
		dungeon_id => $dungeon->id,
		top_left => {x => 1, y => 1},
		bottom_right => {x => 10, y => 10},		
	);
	my $dungeon_room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room(
		$self->{schema}, 
		dungeon_id => $dungeon->id,
		top_left => {x => 11, y => 1},
		bottom_right => {x => 15, y => 10},		
	);
	
	my $type1 = Test::RPG::Builder::CreatureType->build_creature_type($self->{schema});
	
	my $sector = $dungeon_room1->sectors->first;
	my $cg = Test::RPG::Builder::CreatureGroup->build_cg($self->{schema}, dungeon_grid_id => $sector->id, creature_count => 7);
	
	# WHEN
	$dungeon->add_or_remove_creatures(
        {
            type => $type1,
            amount => 3,
        }
    );
    
    # THEN
    my @cgs = $self->{schema}->resultset('CreatureGroup')->search(
        {
            'dungeon_room.dungeon_id' => $dungeon->id,
        },
        {
            join => { 'dungeon_grid' => 'dungeon_room' },
        } 
    );
    is(scalar @cgs, 2, "1 extra cg created");
    
    is($cgs[0]->creatures->count, 8, "First CG has 8 creatures");
    is($cgs[1]->creatures->count, 2, "Second CG has 2 creatures");
    
}

sub test_removing_creatures_basic : Tests(2) {
    my $self = shift;
    
    # GIVEN
	my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema});
	my $dungeon_room1 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room(
		$self->{schema}, 
		dungeon_id => $dungeon->id,
		top_left => {x => 1, y => 1},
		bottom_right => {x => 10, y => 10},		
	);
	my $dungeon_room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room(
		$self->{schema}, 
		dungeon_id => $dungeon->id,
		top_left => {x => 11, y => 1},
		bottom_right => {x => 15, y => 10},		
	);
	
	my $type1 = Test::RPG::Builder::CreatureType->build_creature_type($self->{schema});
	
	my $sector = $dungeon_room1->sectors->first;
	my $cg = Test::RPG::Builder::CreatureGroup->build_cg($self->{schema}, dungeon_grid_id => $sector->id, creature_count => 7, type_id => $type1->id);
	
	# WHEN
	$dungeon->add_or_remove_creatures(
        {
            type => $type1,
            amount => -3,
        }
    );
    
    # THEN
    my @cgs = $self->{schema}->resultset('CreatureGroup')->search(
        {
            'dungeon_room.dungeon_id' => $dungeon->id,
        },
        {
            join => { 'dungeon_grid' => 'dungeon_room' },
        } 
    );
    is(scalar @cgs, 1, "1 cg in dungeon");
    
    is($cgs[0]->creatures->count, 4, "CG has 4 creatures (3 removed)");
}

sub test_removing_creatures_multiple_groups : Tests(3) {
    my $self = shift;
    
    # GIVEN
	my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema});
	my $dungeon_room1 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room(
		$self->{schema}, 
		dungeon_id => $dungeon->id,
		top_left => {x => 1, y => 1},
		bottom_right => {x => 10, y => 10},		
	);
	my $dungeon_room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room(
		$self->{schema}, 
		dungeon_id => $dungeon->id,
		top_left => {x => 11, y => 1},
		bottom_right => {x => 15, y => 10},		
	);
	
	my $type1 = Test::RPG::Builder::CreatureType->build_creature_type($self->{schema});
	my $type2 = Test::RPG::Builder::CreatureType->build_creature_type($self->{schema});
	
	my $sector = $dungeon_room1->sectors->first;
	my $cg1 = Test::RPG::Builder::CreatureGroup->build_cg($self->{schema}, dungeon_grid_id => $sector->id, creature_count => 2, type_id => $type1->id);
	my $cg2 = Test::RPG::Builder::CreatureGroup->build_cg($self->{schema}, dungeon_grid_id => $sector->id, creature_count => 2, type_id => $type2->id);
	my $cg3 = Test::RPG::Builder::CreatureGroup->build_cg($self->{schema}, dungeon_grid_id => $sector->id, creature_count => 2, type_id => $type1->id);
	
	# WHEN
	$dungeon->add_or_remove_creatures(
        {
            type => $type1,
            amount => -5,
        }
    );
    
    # THEN
    my @cgs = $self->{schema}->resultset('CreatureGroup')->search(
        {
            'dungeon_room.dungeon_id' => $dungeon->id,
        },
        {
            join => { 'dungeon_grid' => 'dungeon_room' },
        } 
    );
    is(scalar @cgs, 1, "1 cg in dungeon");
    
    is($cgs[0]->creatures->count, 2, "CG has 2 creatures");
    
    is(grep ({ $_->creature_type_id == $type2->id } $cgs[0]->creatures), 2, "All CGs are of correct type");
}

1;