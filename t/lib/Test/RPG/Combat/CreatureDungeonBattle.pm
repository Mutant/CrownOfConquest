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
use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Dungeon_Room;
use Test::RPG::Builder::CreatureType;
use Test::RPG::Builder::Building;

use RPG::Combat::CreatureDungeonBattle;

sub setup : Tests(setup) {
    my $self = shift;

    Test::RPG::Builder::Day->build_day( $self->{schema} );
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
            x               => 1,
            y               => 1,
            dungeon_room_id => $dungeon_room->id,
        },
    );

    my $dungeon_grid2 = $self->{schema}->resultset('Dungeon_Grid')->create(
        {
            x               => 1,
            y               => 2,
            dungeon_room_id => $dungeon_room->id,
        },
    );

    my $dungeon_path = $self->{schema}->resultset('Dungeon_Sector_Path')->create(
        {
            sector_id   => $dungeon_grid1->id,
            has_path_to => $dungeon_grid2->id,
            distance    => 1,
        }
    );

    $cg->dungeon_grid_id( $dungeon_grid1->id );
    $cg->update;

    $party->dungeon_grid_id( $dungeon_grid1->id );

    my $battle = RPG::Combat::CreatureDungeonBattle->new(
        schema         => $self->{schema},
        party          => $party,
        creature_group => $cg,
        log            => $self->{mock_logger},
    );

    # WHEN
    my $sector = $battle->get_sector_to_flee_to($cg);

    # THEN
    is( $sector->id, $dungeon_grid2->id, "Creatures to flee to second dungeon grid" );

}

sub test_auto_heal_called_for_mayors_group : Tests(1) {
    my $self = shift;

    # GIVEN
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );
    my $dungeon_room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, x_size => 5, 'y_size' => 5, dungeon_id => $dungeon->id );
    my @sectors      = $dungeon_room->sectors;
    my $dungeon_grid = $sectors[0];

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, dungeon_grid_id => $dungeon_grid->id );

    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, gold => 1000, land_id => $dungeon->land_id );
    $town->character_heal_budget(1000);
    $town->update;

    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema} );
    $mayor->mayor_of( $town->id );
    $mayor->update;

    my $char1 = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 5 );

    my $cg = $self->{schema}->resultset('CreatureGroup')->create(
        {
            dungeon_grid_id => $dungeon_grid->id,
        }
    );

    for my $char ( $mayor, $char1 ) {
        $char->creature_group_id( $cg->id );
        $char->update;
    }

    my $battle = RPG::Combat::CreatureDungeonBattle->new(
        schema         => $self->{schema},
        party          => $party,
        creature_group => $cg,
        log            => $self->{mock_logger},
        config         => $self->{config},
    );

    $battle = Test::MockObject::Extends->new($battle);
    $battle->mock( 'check_for_flee', sub { my $inv = shift; $inv->result->{party_fled} = 1; return 1 } );

    # WHEN
    $battle->execute_round;

    # THEN
    $char1->discard_changes;
    is( $char1->hit_points, 10, "Character 1 auto-healed" );
}

sub test_auto_heal_called_for_mayors_group_even_if_mayor_dead : Tests(4) {
    my $self = shift;

    # GIVEN
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );
    my $dungeon_room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, x_size => 5, 'y_size' => 5, dungeon_id => $dungeon->id );
    my @sectors      = $dungeon_room->sectors;
    my $dungeon_grid = $sectors[0];

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 1, dungeon_grid_id => $dungeon_grid->id );

    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, gold => 1000, land_id => $dungeon->land_id );
    $town->character_heal_budget(1000);
    $town->update;

    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema} );
    $mayor->mayor_of( $town->id );
    $mayor->hit_points(0);
    $mayor->update;

    my $char1 = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 5 );

    my $cg = $self->{schema}->resultset('CreatureGroup')->create(
        {
            dungeon_grid_id => $dungeon_grid->id,
        }
    );

    for my $char ( $mayor, $char1 ) {
        $char->creature_group_id( $cg->id );
        $char->update;
    }

    my $battle = RPG::Combat::CreatureDungeonBattle->new(
        schema         => $self->{schema},
        party          => $party,
        creature_group => $cg,
        log            => $self->{mock_logger},
        config         => $self->{config},
    );

    $battle = Test::MockObject::Extends->new($battle);
    $battle->mock( 'check_for_flee', sub { my $inv = shift; $inv->result->{party_fled} = 1; return 1 } );

    # WHEN
    $battle->execute_round;

    # THEN
    $char1->discard_changes;
    is( $char1->hit_points, 10, "Character 1 auto-healed" );

    $mayor->discard_changes;
    is( $mayor->is_dead, 0, "Mayor no longer dead, as opponents fled" );

    my @history = $town->history;
    is( scalar @history, 3, "Two messages added to town's history" );
    is( $history[2]->message, "test was slain in combat. However, as the raiders fled the town's healer resurrected him at no charge",
        "Correct message added to town's history" );
}

sub test_mayor_tactics_bonus_applied_to_guards_af : Tests(2) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema} );
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town->id );

    my $skill = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Tactics',
        }
    );

    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id     => $skill->id,
            character_id => $mayor->id,
            level        => 5,
        }
    );

    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema}, type => 'castle', land_id => $town->land_id );
    my $dungeon_room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, x_size => 5, 'y_size' => 5, dungeon_id => $dungeon->id );
    my @sectors = $dungeon_room->sectors;

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, dungeon_grid_id => $sectors[1]->id );

    my $type = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 5, category_name => 'Guard' );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, type_id => $type->id, creature_count => 2 );
    my @crets = $cg->creatures;

    my $battle = RPG::Combat::CreatureDungeonBattle->new(
        schema         => $self->{schema},
        party          => $party,
        creature_group => $cg,
        log            => $self->{mock_logger},
        config         => $self->{config},
    );

    # WHEN
    my $factors = $battle->combat_factors;

    # THEN
    is( $factors->{creature}{ $crets[0]->id }{af}, 21, "First guard has af bonus" );
    is( $factors->{creature}{ $crets[1]->id }{af}, 21, "Second guard has af bonus" );
}

sub test_mayor_strategy_bonus_applied_to_guards_df : Tests(2) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema} );
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town->id );

    my $skill = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Strategy',
        }
    );

    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id     => $skill->id,
            character_id => $mayor->id,
            level        => 5,
        }
    );

    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema}, type => 'castle', land_id => $town->land_id );
    my $dungeon_room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, x_size => 5, 'y_size' => 5, dungeon_id => $dungeon->id );
    my @sectors = $dungeon_room->sectors;

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, dungeon_grid_id => $sectors[1]->id );

    my $type = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 5, category_name => 'Guard' );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, type_id => $type->id, creature_count => 2 );
    my @crets = $cg->creatures;

    my $battle = RPG::Combat::CreatureDungeonBattle->new(
        schema         => $self->{schema},
        party          => $party,
        creature_group => $cg,
        log            => $self->{mock_logger},
        config         => $self->{config},
    );

    # WHEN
    my $factors = $battle->combat_factors;

    # THEN
    is( $factors->{creature}{ $crets[0]->id }{df}, 21, "First guard has df bonus" );
    is( $factors->{creature}{ $crets[1]->id }{df}, 21, "Second guard has df bonus" );
}

sub test_mayors_guards_dont_attack_him : Tests(2) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, gold => 1000 );

    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema}, type => 'castle', land_id => $town->land_id );
    my $dungeon_room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, x_size => 5, 'y_size' => 5, dungeon_id => $dungeon->id );
    my @sectors = $dungeon_room->sectors;

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 1, dungeon_grid_id => $sectors[0]->id, name => 'Raider' );

    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 0, );
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, name => 'Mayor', party_id => $party2->id );
    $mayor->mayor_of( $town->id );
    $mayor->update;

    my $type = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 5, type => 'Guard', category_name => 'Guard' );
    my $cg = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema}, type_id => $type->id, creature_count => 1, dungeon_grid_id => $sectors[0]->id );
    my ($cret) = $cg->members;

    $mayor->creature_group_id( $cg->id );
    $mayor->update;

    my $battle = RPG::Combat::CreatureDungeonBattle->new(
        schema         => $self->{schema},
        party          => $party,
        creature_group => $cg,
        log            => $self->{mock_logger},
        config         => $self->{config},
    );

    # WHEN
    my @opponents = $battle->opposing_combatants_of($cret);

    # THEN
    is( scalar @opponents, 1, "Guard only has 1 opponent" );
    is( $opponents[0]->party_id, $party->id, "opponent is from opposing party" );
}

1;
