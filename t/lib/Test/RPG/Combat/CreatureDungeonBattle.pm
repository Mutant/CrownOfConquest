use strict;
use warnings;

package Test::RPG::Combat::CreatureDungeonBattle;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::MockObject::Extends;
use Test::More;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::CreatureGroup;
use Test::RPG::Builder::Day;

use RPG::Combat::CreatureDungeonBattle;

sub setup : Tests(setup) {
    my $self = shift;
    
    Test::RPG::Builder::Day->build_day($self->{schema});   
}

sub test_get_sector_to_flee_to : Tests(1) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
    
    my $dungeon_room = $self->{schema}->resultset('Dungeon_Room')->create(
        {
              
        },
    );
    
    my $dungeon_grid1 = $self->{schema}->resultset('Dungeon_Grid')->create(
        {
            x => 1,
            y => 1,
            dungeon_room_id => $dungeon_room->id,
        },
    );

    my $dungeon_grid2 = $self->{schema}->resultset('Dungeon_Grid')->create(
        {
            x => 1,
            y => 2,
            dungeon_room_id => $dungeon_room->id,
        },
    );
    
    my $dungeon_path = $self->{schema}->resultset('Dungeon_Sector_Path')->create(
    	{
    		sector_id => $dungeon_grid1->id,
    		has_path_to => $dungeon_grid2->id,
    		distance => 1,
    	}
    );
    
    $cg->dungeon_grid_id($dungeon_grid1->id);
    $cg->update;
    
    $party->dungeon_grid_id($dungeon_grid1->id);
    
    my $battle = RPG::Combat::CreatureDungeonBattle->new(
        schema             => $self->{schema},
        party              => $party,
        creature_group     => $cg,
        log                => $self->{mock_logger},
    );
    
    # WHEN
    my $sector = $battle->get_sector_to_flee_to($cg);
        
    # THEN
    is($sector->id, $dungeon_grid2->id, "Creatures to flee to second dungeon grid");

}

1;