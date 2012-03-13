use strict;
use warnings;

package Test::RPG::Schema::Bomb;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Land;
use Test::RPG::Builder::Building;
use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Dungeon_Room;

sub test_startup : Tests(startup) {
    my $self = shift;
        
    $self->mock_dice;    
}

sub test_shutdown : Tests(shutdown) {
    my $self = shift;
    
    $self->unmock_dice;   
}

sub test_detonate_on_land_no_buildings : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my ($land) = Test::RPG::Builder::Land->build_land($self->{schema}, x_size => 1, 'y_size' => 1); 
    my $bomb = $self->{schema}->resultset('Bomb')->create(
        {
            land_id => $land->id,
            level => 1,
        }
    );
    
    # WHEN
    my @damaged_upgrades = $bomb->detonate;
    
    # THEN
    $bomb->discard_changes;
    isa_ok($bomb->detonated, 'DateTime', "Bomb marked as detonated");
    
    is(scalar @damaged_upgrades, 0, "No upgrades damaged");      
}

sub test_detonate_on_land_multiple_buildings : Tests(12) {
    my $self = shift;
    
    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land($self->{schema}, x_size => 3, 'y_size' => 3);
    my $bomb = $self->{schema}->resultset('Bomb')->create(
        {
            land_id => $land[4]->id,
            level => 20,
        }
    );
    
    my $building1 = Test::RPG::Builder::Building->build_building($self->{schema}, 
        upgrades => { 
            'Rune Of Protection' => 2,
        },
        land_id => $land[1]->id
    );

    my $building2 = Test::RPG::Builder::Building->build_building($self->{schema}, 
        upgrades => { 
            'Rune of Defence' => 2,
            'Barracks' => 2,
        },
        land_id => $land[2]->id
    );
    
    $self->{rolls} = [2, 10, 10, 10]; 
    
    # WHEN
    my @damaged_upgrades = $bomb->detonate;
    
    # THEN
    $bomb->discard_changes;
    isa_ok($bomb->detonated, 'DateTime', "Bomb marked as detonated");
    
    is(scalar @damaged_upgrades, 2, "2 upgrades damaged");
    
    is($damaged_upgrades[0]->{damage_type}, 'perm', "First upgrade damaged permanently");
    is($damaged_upgrades[0]->{upgrade}->type->name, 'Rune of Protection', "Correct first upgrade");
    is($damaged_upgrades[0]->{upgrade}->level, 1, "Upgrade level reduced");
    is($damaged_upgrades[0]->{upgrade}->damage, 0, "No damage done to upgrade");
    is($damaged_upgrades[0]->{upgrade}->damage_last_done, undef, "Damage last done not set");

    is($damaged_upgrades[1]->{damage_type}, 'temp', "Second upgrade damaged temporarily");
    is($damaged_upgrades[1]->{upgrade}->type->name, 'Rune of Defence', "Correct first upgrade");
    is($damaged_upgrades[1]->{upgrade}->level, 2, "Upgrade level not reduced");
    is($damaged_upgrades[1]->{upgrade}->damage, 1, "Damage done to upgrade");
    isnt($damaged_upgrades[1]->{upgrade}->damage_last_done, undef, "Damage last done set");

}

sub test_detonate_in_castle : Tests(7) {
    my $self = shift;
    
    # GIVEN
	my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema}, type => 'castle');
	my $dungeon_room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room(
		$self->{schema}, 
		dungeon_id => $dungeon->id,
		top_left => {x => 1, y => 1},
		bottom_right => {x => 5, y => 5},		
	);
	my @sectors = $dungeon_room->sectors;
	
    my $bomb = $self->{schema}->resultset('Bomb')->create(
        {
            dungeon_grid_id => $sectors[4]->id,
            level => 20,
        }
    );
        
    my $building = Test::RPG::Builder::Building->build_building($self->{schema}, 
        upgrades => { 
            'Rune Of Protection' => 2,            
        },
        land_id => $dungeon->land_id,
    );
    
    $self->{rolls} = [10, 10]; 
    
    # WHEN
    my @damaged_upgrades = $bomb->detonate;
    
    # THEN
    $bomb->discard_changes;
    isa_ok($bomb->detonated, 'DateTime', "Bomb marked as detonated");
    
    is(scalar @damaged_upgrades, 1, "1 upgrade damaged");    

    is($damaged_upgrades[0]->{damage_type}, 'temp', "Second upgrade damaged temporarily");
    is($damaged_upgrades[0]->{upgrade}->type->name, 'Rune of Protection', "Correct first upgrade");
    is($damaged_upgrades[0]->{upgrade}->level, 2, "Upgrade level not reduced");
    is($damaged_upgrades[0]->{upgrade}->damage, 1, "Damage done to upgrade");
    isnt($damaged_upgrades[0]->{upgrade}->damage_last_done, undef, "Damage last done set");

}


1;
