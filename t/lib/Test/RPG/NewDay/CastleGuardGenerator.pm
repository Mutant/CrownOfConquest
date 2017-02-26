use strict;
use warnings;

package Test::RPG::NewDay::CastleGuardGenerator;

use base qw(Test::RPG::Base::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Dungeon_Room;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::CreatureType;
use Test::RPG::Builder::Character;
use Test::RPG::Builder::CreatureGroup;
use Test::RPG::Builder::Party;

sub setup : Test(setup => 2) {
    my $self = shift;

    use_ok 'RPG::NewDay::Role::CastleGuardGenerator';
    use_ok 'RPG::NewDay::Action::Castles';

    $self->setup_context;

}

sub test_generate_guards_changes_as_per_requests : Tests(3) {
    my $self = shift;

    # GIVEN
    my $castle = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );
    my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, top_left => { x => 1, y => 1 }, bottom_right => { x => 5, y => 5 }, dungeon_id => $castle->id );
    my $room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, top_left => { x => 6, y => 6 }, bottom_right => { x => 10, y => 10 }, dungeon_id => $castle->id );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $castle->land_id, gold => 100, prosperity => 10 );
    my $sector = ( $room->sectors )[0];
    $sector->stairs_up(1);
    $sector->update;

    my $type1 = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 5, category_name => 'Guard', hire_cost => 0 );

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id );
    $character->mayor_of( $town->id );
    $character->update;

    my $hire = $self->{schema}->resultset('Town_Guards')->create(
        {
            town_id          => $town->id,
            creature_type_id => $type1->id,
            amount           => 10,
        }
    );

    my $action = RPG::NewDay::Action::Castles->new( context => $self->{mock_context} );

    # WHEN
    $action->generate_guards($castle);

    # THEN
    my @cgs = $self->{schema}->resultset('CreatureGroup')->search();
    is( scalar @cgs, 2, "Correct number of cgs generated" );

    my $count;
    foreach my $cg (@cgs) {
        foreach my $cret ( $cg->creatures ) {
            $count++;
        }
    }

    is( $count, 10, "Only 10 guards created" );

    $hire->discard_changes;
    is( $hire->amount_working, 10, "Amount working recorded" );
}

sub test_generate_guards_changes_with_existing : Tests(3) {
    my $self = shift;

    # GIVEN
    my $castle = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );
    my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, top_left => { x => 1, y => 1 }, bottom_right => { x => 5, y => 5 }, dungeon_id => $castle->id );
    my $room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, top_left => { x => 6, y => 6 }, bottom_right => { x => 10, y => 10 }, dungeon_id => $castle->id );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $castle->land_id, gold => 100, prosperity => 10 );
    my $sector = ( $room->sectors )[0];
    $sector->stairs_up(1);
    $sector->update;

    my $type1 = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 5, category_name => 'Guard', maint_cost => 10 );

    my @sectors = $room->sectors;

    Test::RPG::Builder::CreatureGroup->build_cg(
        $self->{schema},
        type_id         => $type1->id,
        dungeon_grid_id => $sectors[0]->id,
        creature_count  => 20,
    );

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id );
    $character->mayor_of( $town->id );
    $character->update;

    my $hire = $self->{schema}->resultset('Town_Guards')->create(
        {
            town_id          => $town->id,
            creature_type_id => $type1->id,
            amount           => 10,
        }
    );

    my $action = RPG::NewDay::Action::Castles->new( context => $self->{mock_context} );

    # WHEN
    $action->generate_guards($castle);

    # THEN
    my @cgs = $self->{schema}->resultset('CreatureGroup')->search();
    cmp_ok( scalar @cgs, '>=', 1, "At least one creature group generated" );

    my $count;
    foreach my $cg (@cgs) {
        foreach my $cret ( $cg->creatures ) {
            $count++;
        }
    }

    is( $count, 10, "Only 10 guards created" );
    $town->discard_changes;
    is( $town->gold, 0, "All gold spent" );
}

sub test_generate_guards_mayors_group : Tests(2) {
    my $self = shift;

    # GIVEN
    my $castle = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );
    my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, top_left => { x => 1, y => 1 }, bottom_right => { x => 5, y => 5 }, dungeon_id => $castle->id );
    my $room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, top_left => { x => 6, y => 6 }, bottom_right => { x => 10, y => 10 }, dungeon_id => $castle->id );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $castle->land_id, gold => 100, prosperity => 10 );
    my $sector = ( $room->sectors )[0];
    $sector->stairs_up(1);
    $sector->update;

    my $type1 = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 6, category_name => 'Guard', maint_cost => 0 );
    my $type2 = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 10, category_name => 'Guard', maint_cost => 0 );

    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema} );
    $mayor->mayor_of( $town->id );
    $mayor->update;

    my $action = RPG::NewDay::Action::Castles->new( context => $self->{mock_context} );

    # WHEN
    $action->generate_guards($castle);

    # THEN
    my @cgs = $self->{schema}->resultset('CreatureGroup')->search();
    cmp_ok( scalar @cgs, '>=', 1, "At least one creature group generated" );

    $mayor->discard_changes;
    is( defined $mayor->creature_group_id, 1, "Mayor in a creature group" );
}

sub test_generate_guards_multiple_guard_types : Tests(3) {
    my $self = shift;

    # GIVEN
    my $castle = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );
    my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, top_left => { x => 1, y => 1 }, bottom_right => { x => 5, y => 5 }, dungeon_id => $castle->id );
    my $room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, top_left => { x => 6, y => 6 }, bottom_right => { x => 10, y => 10 }, dungeon_id => $castle->id );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $castle->land_id, gold => 520, prosperity => 10 );
    my $sector = ( $room->sectors )[0];
    $sector->stairs_up(1);
    $sector->update;

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id );
    $character->mayor_of( $town->id );
    $character->update;

    my $type1 = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 5, category_name => 'Guard', maint_cost => 10 );
    my $type2 = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 10, category_name => 'Guard', maint_cost => 20 );
    my $type3 = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 15, category_name => 'Guard', maint_cost => 30 );

    my @sectors = $room->sectors;
    my $count   = 0;
    for my $type ( $type1, $type2, $type3 ) {
        Test::RPG::Builder::CreatureGroup->build_cg(
            $self->{schema},
            type_id         => $type->id,
            dungeon_grid_id => $sectors[$count]->id,
            creature_count  => 5,
        );
        $count++;

        my $hire = $self->{schema}->resultset('Town_Guards')->create(
            {
                town_id          => $town->id,
                creature_type_id => $type->id,
                amount           => 10,
            }
        );
    }

    my $action = RPG::NewDay::Action::Castles->new( context => $self->{mock_context} );

    # WHEN
    $action->generate_guards($castle);

    # THEN
    my @cgs = $self->{schema}->resultset('CreatureGroup')->search();
    is( scalar @cgs, 4, "Correct number of cgs generated" );

    $count = 0;
    foreach my $cg (@cgs) {
        foreach my $cret ( $cg->creatures ) {
            $count++;
        }
    }

    is( $count, 27, "Only 10 guards created" );

    my $hist_rec = $self->{schema}->resultset('Town_History')->find(
        {
            town_id => $town->id,
            message => 'Guard Wages',
        }
    );
    is( $hist_rec->value, 510, "Correct expense record written" );
}

sub test_generate_guards_multiple_guard_types_firings_needed : Tests(3) {
    my $self = shift;

    # GIVEN
    my $castle = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );
    my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, top_left => { x => 1, y => 1 }, bottom_right => { x => 5, y => 5 }, dungeon_id => $castle->id );
    my $room2 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, top_left => { x => 6, y => 6 }, bottom_right => { x => 10, y => 10 }, dungeon_id => $castle->id );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $castle->land_id, gold => 520, prosperity => 10 );
    my $sector = ( $room->sectors )[0];
    $sector->stairs_up(1);
    $sector->update;

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id );
    $character->mayor_of( $town->id );
    $character->update;

    my $type1 = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 5, category_name => 'Guard', maint_cost => 10 );
    my $type2 = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 10, category_name => 'Guard', maint_cost => 20 );
    my $type3 = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 15, category_name => 'Guard', maint_cost => 30 );

    my @sectors = $room->sectors;
    my $count   = 0;
    for my $type ( $type1, $type2, $type3 ) {
        Test::RPG::Builder::CreatureGroup->build_cg(
            $self->{schema},
            type_id         => $type->id,
            dungeon_grid_id => $sectors[$count]->id,
            creature_count  => 10,
        );
        $count++;

        my $hire = $self->{schema}->resultset('Town_Guards')->create(
            {
                town_id          => $town->id,
                creature_type_id => $type->id,
                amount           => 10,
            }
        );
    }

    my $action = RPG::NewDay::Action::Castles->new( context => $self->{mock_context} );

    # WHEN
    $action->generate_guards($castle);

    # THEN
    my @cgs = $self->{schema}->resultset('CreatureGroup')->search();
    is( scalar @cgs, 3, "Correct number of cgs generated" );

    $count = 0;
    foreach my $cg (@cgs) {
        foreach my $cret ( $cg->creatures ) {
            $count++;
        }
    }

    is( $count, 27, "Only 10 guards created" );

    my $hist_rec = $self->{schema}->resultset('Town_History')->find(
        {
            town_id => $town->id,
            message => 'Guard Wages',
        }
    );
    is( $hist_rec->value, 510, "Correct expense record written" );
}

sub test_check_for_mayor_replacement_dead_mayor : Tests(2) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema} );
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 0, class => 'Warrior' );
    $mayor->mayor_of( $town->id );
    $mayor->update;

    my $action = RPG::NewDay::Action::Castles->new( context => $self->{mock_context} );

    # WHEN
    $action->check_for_mayor_replacement( $town, $town->mayor );

    # THEN
    $mayor->discard_changes;
    is( $mayor->mayor_of, undef, "Mayor is no longer mayor" );

    my $new_mayor = $town->mayor;
    isa_ok( $new_mayor, 'RPG::Schema::Character', "New mayor appointed" );
}

sub test_check_for_mayor_replacement_dead_mayor_in_combat : Tests(1) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema} );
    my $cg   = Test::RPG::Builder::CreatureGroup->build_cg( $self->{schema} );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, in_combat_with => $cg->id );

    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 0, class => 'Warrior', creature_group_id => $cg->id );
    $mayor->mayor_of( $town->id );
    $mayor->update;

    my $action = RPG::NewDay::Action::Castles->new( context => $self->{mock_context} );

    # WHEN
    $action->check_for_mayor_replacement( $town, $town->mayor );

    # THEN
    $mayor->discard_changes;
    is( $mayor->mayor_of, $town->id, "Mayor is still mayor" );
}

sub test_generate_mayors_group : Tests() {
    my $self = shift;

    # GIVEN
    my $castle = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema} );
    my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, top_left => { x => 1, y => 1 }, bottom_right => { x => 10, y => 10 }, dungeon_id => $castle->id );
    my ($stairs_sector) = $room->sectors;
    $stairs_sector->update( { stairs_up => 1 } );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $castle->land_id );
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town->id, party_id => $party->id, );
    my $char = Test::RPG::Builder::Character->build_character( $self->{schema}, status => 'mayor_garrison', status_context => $town->id, party_id => $party->id, );

    my $action = RPG::NewDay::Action::Castles->new( context => $self->{mock_context} );

    my $history_rec = $self->{schema}->resultset('Party_Mayor_History')->create(
        {
            party_id           => $mayor->party_id,
            town_id            => $town->id,
            lost_mayoralty_day => undef,
        }
    );

    # WHEN
    $action->generate_mayors_group( $castle, $town, $mayor );

    # THEN
    my $cg = $mayor->creature_group;
    is( defined $cg, 1, "CG generated for mayor" );

    my ($sector) = grep { $_->id == $cg->dungeon_grid_id } $room->sectors;
    is( defined $sector, 1, "CG added to sector in the castle" );

    $char->discard_changes;
    is( $char->creature_group_id, $cg->id, "Garrison char added to cg" );

    $history_rec->discard_changes;
    is( $history_rec->creature_group_id, $cg->id, "CG id recorded in history record" );
}

1;
