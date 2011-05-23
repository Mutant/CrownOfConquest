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
use Test::RPG::Builder::Dungeon_Grid;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::Character;

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

sub test_auto_heal_called_for_mayors_group : Tests(1) {
    my $self = shift;

    # GIVEN
    my $dungeon_grid = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid($self->{schema});

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, dungeon_grid_id => $dungeon_grid->id );
    
    my $town = Test::RPG::Builder::Town->build_town($self->{schema}, prosperity => 50, gold => 1000);
    $town->character_heal_budget(1000);
    $town->update;
    
    my $mayor = Test::RPG::Builder::Character->build_character($self->{schema});
    $mayor->mayor_of($town->id);
    $mayor->update;
    
    my $char1 = Test::RPG::Builder::Character->build_character($self->{schema}, hit_points => 5);    
    
    my $cg = $self->{schema}->resultset('CreatureGroup')->create(
        {
            dungeon_grid_id => $dungeon_grid->id,
        }
    );
 
    for my $char ($mayor, $char1) {
        $char->creature_group_id($cg->id);
        $char->update;   
    }     
    

    my $battle = RPG::Combat::CreatureDungeonBattle->new(
        schema             => $self->{schema},
        party              => $party,
        creature_group     => $cg,
        log                => $self->{mock_logger},
        config             => $self->{config},
    );
    
    $battle = Test::MockObject::Extends->new($battle);
    $battle->mock('check_for_flee', sub { my $inv = shift; $inv->result->{creatures_fled} = 1; return 1 } );            
    
    # WHEN
    $battle->execute_round;
    
    # THEN
    $char1->discard_changes;    
    is($char1->hit_points, 10, "Character 1 auto-healed");
    
}

1;