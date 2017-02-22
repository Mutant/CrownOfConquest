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
use Test::RPG::Builder::Garrison;

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

sub test_detonate_on_land_multiple_buildings : Tests(14) {
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
    
    $self->{rolls} = [2, 50, 10, 10, 1]; 
    
    # WHEN
    my @damaged_upgrades = $bomb->detonate;
    
    # THEN
    $bomb->discard_changes;
    isa_ok($bomb->detonated, 'DateTime', "Bomb marked as detonated");
    
    is(scalar @damaged_upgrades, 2, "2 upgrades damaged");
    
    
    is($damaged_upgrades[0]->{damage_done}{temp}, undef, "Upgrade not damaged temporarily");
    is($damaged_upgrades[0]->{damage_done}{perm}, 1, "Upgrade damaged permanently");    
    is($damaged_upgrades[0]->{upgrade}->type->name, 'Rune of Protection', "Correct first upgrade");
    is($damaged_upgrades[0]->{upgrade}->level, 1, "Upgrade level reduced");
    is($damaged_upgrades[0]->{upgrade}->damage, 0, "No damage done to upgrade");
    is($damaged_upgrades[0]->{upgrade}->damage_last_done, undef, "Damage last done not set");

    is($damaged_upgrades[1]->{damage_done}{temp}, 1, "Upgrade damaged temporarily");
    is($damaged_upgrades[1]->{damage_done}{perm}, undef, "Upgrade not damaged permanently");    
    is($damaged_upgrades[1]->{upgrade}->type->name, 'Rune of Defence', "Correct first upgrade");
    is($damaged_upgrades[1]->{upgrade}->level, 2, "Upgrade level not reduced");
    is($damaged_upgrades[1]->{upgrade}->damage, 1, "Damage done to upgrade");
    isnt($damaged_upgrades[1]->{upgrade}->damage_last_done, undef, "Damage last done set");

}

sub test_detonate_in_castle : Tests(8) {
    my $self = shift;
    
    # GIVEN
	my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema}, type => 'castle');
	my $dungeon_room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room(
		$self->{schema}, 
		dungeon_id => $dungeon->id,
		top_left => {x => 1, y => 1},
		bottom_right => {x => 5, y => 5},
		make_stairs => 1,
	);
	my @sectors = $dungeon_room->sectors;
	
    my $bomb = $self->{schema}->resultset('Bomb')->create(
        {
            dungeon_grid_id => $sectors[24]->id,
            level => 20,
        }
    );
        
    my $building = Test::RPG::Builder::Building->build_building($self->{schema}, 
        upgrades => { 
            'Rune Of Protection' => 2,            
        },
        land_id => $dungeon->land_id,
    );
    
    $self->{rolls} = [10, 10, 1]; 
    
    # WHEN
    my @damaged_upgrades = $bomb->detonate;
    
    # THEN
    $bomb->discard_changes;
    isa_ok($bomb->detonated, 'DateTime', "Bomb marked as detonated");
    
    is(scalar @damaged_upgrades, 1, "1 upgrade damaged");    

    is($damaged_upgrades[0]->{damage_done}{temp}, 1, "Second upgrade damaged temporarily");
    is($damaged_upgrades[0]->{damage_done}{perm}, undef, "Second upgrade not damaged permanently");
    is($damaged_upgrades[0]->{upgrade}->type->name, 'Rune of Protection', "Correct first upgrade");
    is($damaged_upgrades[0]->{upgrade}->level, 2, "Upgrade level not reduced");
    is($damaged_upgrades[0]->{upgrade}->damage, 1, "Damage done to upgrade");
    isnt($damaged_upgrades[0]->{upgrade}->damage_last_done, undef, "Damage last done set");
}

sub test_detonate_reduces_residents_bonuses : Tests(18) {
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
            'Rune of Defence' => 2,
            'Rune of Attack' => 3,
        },
        land_id => $land[1]->id
    );

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, land_id => $land[1]->id, character_count => 0 );
    my $character1 = Test::RPG::Builder::Character->build_character( $self->{schema}, agility => 10, strength => 10, garrison_id => $garrison->id );
    is($character1->defence_factor, 24, "Character in garrison has correct DF before detonation");
    is($character1->attack_factor, 25, "Character in garrison has correct AF before detonation");
    
    $self->{rolls} = [2, 100, 10, 10, 1]; 
    
    # WHEN
    my @damaged_upgrades = $bomb->detonate;
    
    # THEN
    $bomb->discard_changes;
    isa_ok($bomb->detonated, 'DateTime', "Bomb marked as detonated");
    
    is(scalar @damaged_upgrades, 2, "2 upgrades damaged");
    
    my $first_damaged_rune  = $damaged_upgrades[0]->{upgrade}->type->name;
    my $second_damaged_rune = $damaged_upgrades[1]->{upgrade}->type->name;
    my $first_level_reduction  = $first_damaged_rune eq 'Rune of Defence' ? 1 : 2;
    my $second_level_reduction = $first_damaged_rune eq 'Rune of Defence' ? 3 : 2;
    
    like($first_damaged_rune,  qr{^Rune of (Defence|Attack)$}, "First rune name is correct");
    like($second_damaged_rune, qr{^Rune of (Defence|Attack)$}, "Second rune name is correct");
       
    is($damaged_upgrades[0]->{damage_done}{temp}, undef, "Upgrade not damaged temporarily");
    is($damaged_upgrades[0]->{damage_done}{perm}, 1, "Upgrade damaged permanently");    
    is($damaged_upgrades[0]->{upgrade}->level, $first_level_reduction, "Upgrade level reduced");
    is($damaged_upgrades[0]->{upgrade}->damage, 0, "No damage done to upgrade");
    is($damaged_upgrades[0]->{upgrade}->damage_last_done, undef, "Damage last done not set");
        
    is($damaged_upgrades[1]->{damage_done}{temp}, 1, "Upgrade damaged temporarily");
    is($damaged_upgrades[1]->{damage_done}{perm}, undef, "Upgrade not damaged permanently");    
    is($damaged_upgrades[1]->{upgrade}->level, $second_level_reduction, "Upgrade level not reduced");
    is($damaged_upgrades[1]->{upgrade}->damage, 1, "Damage done to upgrade");
    isnt($damaged_upgrades[1]->{upgrade}->damage_last_done, undef, "Damage last done set");    
    
   
    $character1->discard_changes;
    is($character1->defence_factor, 19, "Character in garrison has correct DF after detonation");
    is($character1->attack_factor, 20, "Character in garrison has correct AF after detonation");

}


1;
