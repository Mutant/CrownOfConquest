use strict;
use warnings;

package Test::RPG::NewDay::Mayor;

use base qw(Test::RPG::Base::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use DateTime;

use Test::MockObject::Extends;
use Test::More;

use Test::RPG::Builder::Town;
use Test::RPG::Builder::Day;
use Test::RPG::Builder::Character;
use Test::RPG::Builder::Item;
use Test::RPG::Builder::Item_Type;
use Test::RPG::Builder::Kingdom;
use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::CreatureType;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Dungeon_Room;
use Test::RPG::Builder::Building;

sub setup : Test(setup) {
    my $self = shift;

    $self->setup_context;

    $self->mock_dice;

    undef $self->{rolls};
}

sub startup : Test(startup => 1) {
    my $self = shift;

    use_ok('RPG::NewDay::Action::Mayor');

}

sub test_process_revolt_overthrow : Tests(7) {
    my $self = shift;

    # GIVEN
    $self->{roll_result} = 20;

    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, );
    $town->peasant_state('revolt');
    $town->update;

    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    $character->mayor_of( $town->id );
    $character->update;

    my $garrison_character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    $garrison_character->status('mayor_garrison');
    $garrison_character->status_context( $town->id );
    $garrison_character->update;

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    $self->{config}{level_hit_points_max}{test_class} = 6;

    # WHEN
    $action->process_revolt($town);

    # THEN
    $character->discard_changes;
    is( $character->mayor_of, undef, "Character no longer mayor of town" );

    $town->discard_changes;
    is( $town->peasant_state, undef, "Peasants no longer in revolt" );
    is( $town->mayor_rating,  0,     "Mayor approval reset" );

    my $new_mayor = $self->{schema}->resultset('Character')->find(
        {
            mayor_of => $town->id,
        }
    );
    is( defined $new_mayor, 1, "New mayor generated" );

    $garrison_character->discard_changes;
    is( $garrison_character->status, 'morgue', "Garrison character placed in morgue" );
    is( $garrison_character->status_context, $town->id, "Garrsion character has correct status context" );
    is( $garrison_character->hit_points, 0, "Garrison character has 0 hps" );
}

sub test_process_revolt_with_negotiation : Tests(1) {
    my $self = shift;

    # GIVEN
    $self->{roll_result} = 20;

    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, );
    $town->peasant_state('revolt');
    $town->update;

    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    $character->mayor_of( $town->id );
    $character->update;

    my $skill = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Negotiation',
        }
    );

    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id     => $skill->id,
            character_id => $character->id,
            level        => 10,
        }
    );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    $self->{config}{level_hit_points_max}{test_class} = 6;

    # WHEN
    $action->process_revolt($town);

    # THEN
    $character->discard_changes;
    is( defined $character->mayor_of, 1, "Character still mayor of town due to negotaition bonus" );
}

sub test_process_revolt_peasants_do_damage : Tests(4) {
    my $self = shift;

    # GIVEN
    $self->{rolls} = [ 30, 3 ];

    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, );
    $town->peasant_state('revolt');
    $town->update;

    my $building = Test::RPG::Builder::Building->build_building( $self->{schema},
        upgrades => {
            'Rune Of Protection' => 2,
        },
        land_id    => $town->land_id,
        owner_id   => $town->id,
        owner_type => 'town',
    );

    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    $character->mayor_of( $town->id );
    $character->update;

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    $self->{config}{level_hit_points_max}{test_class} = 6;

    # WHEN
    $action->process_revolt($town);

    # THEN
    $character->discard_changes;
    is( $character->mayor_of, $town->id, "Character still mayor of town" );

    $town->discard_changes;
    is( $town->peasant_state, 'revolt', "Peasants still in revolt" );

    my @upgrade = $building->upgrades;
    is( @upgrade,           1, "One building upgrade" );
    is( $upgrade[0]->level, 0, "Building's upgrade level reduced" );

    undef $self->{rolls};
}

sub test_process_revolt_party_over_limit : Tests(4) {
    my $self = shift;

    # GIVEN
    $self->{rolls}       = [64];
    $self->{roll_result} = 1;

    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, peasant_state => 'revolt' );

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town->id, party_id => $party->id );

    $self->{config}{level_hit_points_max}{test_class} = 6;

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->process_revolt($town);

    # THEN
    $character->discard_changes;
    is( $character->mayor_of, undef, "Character no longer mayor of town" );

    $town->discard_changes;
    is( $town->peasant_state, undef, "Peasants no longer in revolt" );
    is( $town->mayor_rating,  0,     "Mayor approval reset" );

    my $new_mayor = $self->{schema}->resultset('Character')->find(
        {
            mayor_of => $town->id,
        }
    );
    is( defined $new_mayor, 1, "New mayor generated" );
}

sub test_check_for_pending_mayor_expiry : Tests(2) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, );
    $town->pending_mayor(1);
    $town->pending_mayor_date( DateTime->now()->subtract( hours => 24, seconds => 10 ) );
    $town->update;

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->check_for_pending_mayor_expiry($town);

    # THEN
    $town->discard_changes;
    is( $town->pending_mayor,      undef, "Pending mayor cleared" );
    is( $town->pending_mayor_date, undef, "Pending mayor date cleared" );
}

sub test_refresh_mayor : Tests(6) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 5, max_hit_point => 10 );
    $character->create_item_grid;
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema} );
    my $ammo_type = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema},
        variables => [ { name => 'Quantity', create_on_insert => 1 } ],
    );
    my $ranged = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema},
        category_name => 'Ranged Weapon',
        attributes => [ { item_attribute_name => 'Ammunition', item_attribute_value => $ammo_type->id } ]
    );
    my $item = Test::RPG::Builder::Item->build_item( $self->{schema},
        item_type_id => $ranged->id,
        char_id      => $character->id,
        variables => [ { item_variable_name => 'Durability', item_variable_value => 10, max_value => 100 } ],
        equip_place_id => 2,
    );
    my $ammo = Test::RPG::Builder::Item->build_item( $self->{schema},
        item_type_id   => $ammo_type->id,
        char_id        => $character->id,
        no_equip_place => 1,
    );
    $ammo->variable( 'Quantity', 10 );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->refresh_mayor( $character, $town );

    # THEN
    $character->discard_changes;
    is( $character->hit_points, 10, "Mayor healed to full hit points" );
    my @items = $character->items;
    is( scalar @items, 3, "Mayor now has 2 items" );
    my ($new_ammo) = grep { $_->id != $item->id && $_->id != $ammo->id } @items;
    is( $new_ammo->item_type_id, $ammo_type->id, "Ammo created with correct item type" );
    is( $new_ammo->variable('Quantity'), 200, "Quantity of ammo set correctly" );
    isnt( $new_ammo->start_sector, undef, "Ammo added to inventory grid" );

    $item->discard_changes;
    is( $item->variable('Durability'), 100, "Weapon repaired" );
}

sub test_refresh_mayor_dead_garrison_characters : Test(5) {
    my $self = shift;

    # GIVEN
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema} );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, gold => 300, character_heal_budget => 310 );
    my $char1 = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 0, max_hit_points => 10, level => 1 );
    my $char2 = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 0, max_hit_points => 10, level => 2 );

    for my $char ( $char1, $char2 ) {
        $char->status('mayor_garrison');
        $char->status_context( $town->id );
        $char->update;
    }

    my $hist_rec = $self->{schema}->resultset('Town_History')->create(
        {
            town_id => $town->id,
            type    => 'expense',
            message => 'Town Garrison Healing',
            value   => 10,
            day_id  => $self->{mock_context}->current_day->id,
        }
    );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->refresh_mayor( $mayor, $town );

    # THEN
    $char1->discard_changes;
    is( $char1->hit_points, 1, "Character 1 ressurected" );

    $char2->discard_changes;
    is( $char2->hit_points, 1, "Character 2 ressurected" );

    $town->discard_changes;
    is( $town->gold, 0, "Town used up gold" );

    $hist_rec->discard_changes;
    is( $hist_rec->value, 310, "Cost of healing recorded" );

    my $town_message = $town->find_related(
        'history',
        {
            type => 'mayor_news',
        }
    );
    is( $town_message->message, "The town healer resurrected 2 town garrison characters at the cost of 300 gold.", "Correct message added to mayor history" );

}

sub test_refresh_mayor_dead_garrison_characters_not_enough_budget : Test(2) {
    my $self = shift;

    # GIVEN
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema} );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, gold => 100, character_heal_budget => 100 );
    my $char = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 0, max_hit_points => 10, level => 1 );
    $char->status('mayor_garrison');
    $char->status_context( $town->id );
    $char->update;

    my $hist_rec = $self->{schema}->resultset('Town_History')->create(
        {
            town_id => $town->id,
            type    => 'expense',
            message => 'Town Garrison Healing',
            value   => 10,
            day_id  => $self->{mock_context}->current_day->id,
        }
    );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->refresh_mayor( $mayor, $town );

    # THEN
    $char->discard_changes;
    is( $char->hit_points, 0, "Character not resurrected" );

    $town->discard_changes;
    is( $town->gold, 100, "Town still has gold" );

}

sub test_refresh_mayor_dead_garrison_characters_not_enough_gold : Test(2) {
    my $self = shift;

    # GIVEN
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema} );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, gold => 90, character_heal_budget => 100 );
    my $char = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 0, max_hit_points => 10, level => 1 );
    $char->status('mayor_garrison');
    $char->status_context( $town->id );
    $char->update;

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->refresh_mayor( $mayor, $town );

    # THEN
    $char->discard_changes;
    is( $char->hit_points, 0, "Character not resurrected" );

    $town->discard_changes;
    is( $town->gold, 90, "Town still has gold" );

}

sub test_generate_advice : Tests(3) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, advisor_fee => 50, gold => 20 );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    undef $self->{roll_result};

    # WHEN
    $action->generate_advice( $town, 'garrison' );

    # THEN
    my $advice = $self->{schema}->resultset('Town_History')->find(
        {
            town_id => $town->id,
            type    => 'advice',
        }
    );
    is( defined $advice, 1, "Advice generated" );
    is( $advice->message, "You could use some more protection. Adding more characters to the town's garrison will give you an edge",
        "correct advice" );

    $town->discard_changes;
    is( $town->gold, 0, "Town gold reduced" );
}

sub test_calculate_kingdom_tax : Tests(2) {
    my $self = shift;

    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema}, mayor_tax => 10, gold => 100 );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, gold => 1000, kingdom_id => $kingdom->id );

    my $day = $self->{mock_context}->current_day;

    $town->add_to_history(
        {
            type    => 'income',
            value   => 100,
            message => 'Income 1',
            day_id  => $day->id,
        }
    );

    $town->add_to_history(
        {
            type    => 'income',
            value   => 150,
            message => 'Income 2',
            day_id  => $day->id,
        }
    );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->calculate_kingdom_tax($town);

    # THEN
    $town->discard_changes;
    is( $town->gold, 975, "Town gold decreased" );

    $kingdom->discard_changes;
    is( $kingdom->gold, 125, "Kingdom gold increased" );
}

sub test_calculate_kingdom_tax_free_town : Tests(1) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, gold => 1000 );

    my $day = $self->{mock_context}->current_day;

    $town->add_to_history(
        {
            type    => 'income',
            value   => 100,
            message => 'Income 1',
            day_id  => $day->id,
        }
    );

    $town->add_to_history(
        {
            type    => 'income',
            value   => 150,
            message => 'Income 2',
            day_id  => $day->id,
        }
    );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->calculate_kingdom_tax($town);

    # THEN
    $town->discard_changes;
    is( $town->gold, 1000, "No tax paid, as this is a free town" );

}

sub test_check_for_allegiance_change : Tests(1) {
    my $self = shift;

    # GIVEN
    my $kingdom1 = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my $kingdom2 = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my $kingdom3 = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, kingdom_id => $kingdom1->id,
        kingdom_loyalty => {
            $kingdom1->id => 10,
            $kingdom2->id => 20,
            $kingdom3->id => 30,
          }
    );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    $self->{roll_result} = 5;

    # WHEN
    $action->check_for_allegiance_change($town);

    # THEN
    $town->discard_changes;
    is( $town->location->kingdom_id, $kingdom3->id, "Allegiance of town changed" );
}

sub test_check_for_allegiance_change_negative_loyalty : Tests(1) {
    my $self = shift;

    # GIVEN
    my $kingdom1 = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my $kingdom2 = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my $kingdom3 = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my $kingdom4 = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema}, active => 0 );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, kingdom_id => $kingdom1->id,
        kingdom_loyalty => {
            $kingdom1->id => -10,
            $kingdom2->id => -5,
          }
    );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    $self->{roll_result} = 3;

    # WHEN
    $action->check_for_allegiance_change($town);

    # THEN
    $town->discard_changes;
    is( $town->location->kingdom_id, $kingdom3->id, "Allegiance of town changed" );
}

sub test_check_for_allegiance_change_existing_kingdom_ok : Tests(1) {
    my $self = shift;

    # GIVEN
    my $kingdom1 = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my $kingdom2 = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, kingdom_id => $kingdom1->id,
        kingdom_loyalty => {
            $kingdom1->id => 98,
            $kingdom2->id => 97,
          }
    );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    $self->{rolls} = [ 3, 10 ];

    # WHEN
    $action->check_for_allegiance_change($town);

    # THEN
    $town->discard_changes;
    is( $town->location->kingdom_id, $kingdom1->id, "Allegiance of town not changed" );
}

sub test_check_for_allegiance_change_existing_kingdom_goes_neutral : Tests(1) {
    my $self = shift;

    # GIVEN
    my $kingdom1 = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my $kingdom2 = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, kingdom_id => $kingdom1->id,
        kingdom_loyalty => {
            $kingdom1->id => 98,
            $kingdom2->id => 97,
          }
    );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    $self->{rolls} = [ 3, 8 ];

    # WHEN
    $action->check_for_allegiance_change($town);

    # THEN
    $town->discard_changes;
    is( $town->location->kingdom_id, undef, "Town is now neutral" );
}

sub test_caclulate_approval_basic : Tests(1) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema} );
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town->id );
    my $castle = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema}, type => 'castle', land_id => $town->land_id );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->calculate_approval($town);

    # THEN
    $town->discard_changes;
    is( $town->mayor_rating, -10, "Mayor rating reduced" );

}

sub test_caclulate_approval_mayoralty_changed : Tests(1) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema} );
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town->id );
    my $castle = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema}, type => 'castle', land_id => $town->land_id );

    my $pmh = $self->{schema}->resultset('Party_Mayor_History')->create(
        {
            town_id           => $town->id,
            got_mayoralty_day => $self->{mock_context}->yesterday->id,
            mayor_name        => 'Mayor',
            character_id      => $mayor->id,
            party_id          => 1,
        }
    );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->calculate_approval($town);

    # THEN
    $town->discard_changes;
    is( $town->mayor_rating, 0, "Mayor rating unchanged" );

}

sub test_caclulate_approval_with_charisma : Tests(1) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema} );
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town->id );
    my $castle = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema}, type => 'castle', land_id => $town->land_id );

    my $skill = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Charisma',
        }
    );

    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id     => $skill->id,
            character_id => $mayor->id,
            level        => 4,
        }
    );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->calculate_approval($town);

    # THEN
    $town->discard_changes;
    is( $town->mayor_rating, -10, "Mayor rating reduced" );

}

sub test_caclulate_approval_rune_adjustment : Tests(1) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema} );
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town->id );
    my $castle = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema}, type => 'castle', land_id => $town->land_id );
    my $building = Test::RPG::Builder::Building->build_building( $self->{schema}, owner_type => 'town', owner_id => $town->id, land_id => $town->land_id );
    my $upgrade_type = $self->{schema}->resultset('Building_Upgrade_Type')->find(
        {
            name => 'Rune of Defence',
        }
    );
    $building->add_to_upgrades(
        {
            type_id => $upgrade_type->type_id,
            level   => 4,
        }
    );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->calculate_approval($town);

    # THEN
    $town->discard_changes;
    is( $town->mayor_rating, -10, "Mayor rating reduced" );
}

sub test_collect_tax : Tests(6) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, peasant_tax => 10, gold => 0 );
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town->id );

    $self->{roll_result} = 20;

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->collect_tax( $town, $mayor );

    # THEN
    $town->discard_changes;
    is( $town->gold, 770, "Tax collected" );

    is( $town->history->count, 2, "Messages added to town's history" );
    my @history = $town->history;
    is( $history[0]->message, "The mayor collected 770 gold tax from the peasants", "Correct town message" );

    is( $history[1]->type, "income", "Second history line records income" );
    is( $history[1]->value, "770", "Second history line records income value" );
    is( $history[1]->message, "Peasant Tax", "Second history line records income label" );
}

sub test_collect_tax_with_leadership : Tests(1) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, peasant_tax => 10, gold => 0 );
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town->id );

    $self->{roll_result} = 20;

    my $skill = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Leadership',
        }
    );

    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id     => $skill->id,
            character_id => $mayor->id,
            level        => 5,
        }
    );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->collect_tax( $town, $mayor );

    # THEN
    $town->discard_changes;
    is( $town->gold, 1270, "Tax collected" );
}

sub test_pay_trap_maintenance : Tests(5) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, gold => 100 );
    $town->trap_level(2);
    $town->update;

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->pay_trap_maintenance($town);

    # THEN
    $town->discard_changes;
    is( $town->gold, 90, "Trap maintenance paid" );

    is( $town->history->count, 1, "Message added to town's history" );
    my @history = $town->history;

    is( $history[0]->type, "expense", "Second history line records expense" );
    is( $history[0]->value, "10", "Second history line records expense value" );
    is( $history[0]->message, "Trap Maintenance", "Second history line records expense label" );

}

sub test_pay_trap_maintenance_couldnt_afford : Tests(3) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, gold => 5 );
    $town->trap_level(2);
    $town->update;

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->pay_trap_maintenance($town);

    # THEN
    $town->discard_changes;
    is( $town->gold,       5, "No trap maintenance paid" );
    is( $town->trap_level, 1, "Trap level decreased" );

    is( $town->history->count, 0, "No messages added to town's history" );
}

sub test_train_guards_gold_limited : Tests(9) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, gold => 1100, prosperty => 30 );

    my $type1 = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 5, category_name => 'Guard', hire_cost => 100 );
    my $type2 = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 10, category_name => 'Guard', hire_cost => 200 );

    $self->{roll_result} = 1;

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->train_guards($town);

    # THEN
    my @hires = $self->{schema}->resultset('Town_Guards')->search(
        {
            town_id => $town->id,
        },
    );
    is( scalar @hires, 2, "2 hire records created" );

    is( $hires[0]->creature_type_id, $type1->id, "First hire record is correct cret type id" );
    is( $hires[0]->amount, 1, "Correct number hired for first guard type" );

    is( $hires[1]->creature_type_id, $type2->id, "Second hire record is correct cret type id" );
    is( $hires[1]->amount, 5, "Correct number hired for second guard type" );

    $town->discard_changes;
    is( $town->gold, 0, "Correct amount of gold spent" );

    my @history = $town->history;
    is( scalar @history,    1,         "1 item in history" );
    is( $history[0]->type,  'expense', "History is an expense" );
    is( $history[0]->value, '1100',    "Value is correct" );

}

sub test_train_guards_level_limited : Tests(9) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, gold => 10000, prosperty => 1 );

    my $type1 = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 5, category_name => 'Guard', hire_cost => 100 );
    my $type2 = Test::RPG::Builder::CreatureType->build_creature_type( $self->{schema}, creature_level => 10, category_name => 'Guard', hire_cost => 200 );

    $self->{roll_result} = 1;

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->train_guards($town);

    # THEN
    my @hires = $self->{schema}->resultset('Town_Guards')->search(
        {
            town_id => $town->id,
        },
    );
    is( scalar @hires, 2, "2 hire records created" );

    is( $hires[0]->creature_type_id, $type1->id, "First hire record is correct cret type id" );
    is( $hires[0]->amount, 0, "Correct number hired for first guard type" );

    is( $hires[1]->creature_type_id, $type2->id, "Second hire record is correct cret type id" );
    is( $hires[1]->amount, 31, "Correct number hired for second guard type" );

    $town->discard_changes;
    is( $town->gold, 3800, "Correct amount of gold spent" );

    my @history = $town->history;
    is( scalar @history,    1,         "1 item in history" );
    is( $history[0]->type,  'expense', "History is an expense" );
    is( $history[0]->value, '6200',    "Value is correct" );

}

sub test_no_tax_collected_when_revolt_started : Tests(2) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, peasant_tax => 40 );
    my $castle = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema}, type => 'castle', land_id => $town->land_id );
    my $room1 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, x_size => 5, 'y_size' => 4, dungeon_id => $castle->id, make_stairs => 1 );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );

    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id );
    $character->mayor_of( $town->id );
    $character->update;

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->process_town($town);

    # THEN
    $town->discard_changes;
    is( $town->peasant_state, 'revolt', "Town is in revolt because peasant tax was too high" );
    is( $town->gold, 0, "Town's gold is 0 - no tax collected" );
}

sub test_no_tax_collected_when_peasnt_tax_is_0 : Tests(2) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 73, peasant_tax => 0 );
    my $castle = Test::RPG::Builder::Dungeon->build_dungeon( $self->{schema}, type => 'castle', land_id => $town->land_id );
    my $room1 = Test::RPG::Builder::Dungeon_Room->build_dungeon_room( $self->{schema}, x_size => 5, 'y_size' => 4, dungeon_id => $castle->id, make_stairs => 1 );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, level => 20 );

    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id );
    $character->mayor_of( $town->id );
    $character->update;

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->process_town($town);

    # THEN
    $town->discard_changes;
    is( $town->peasant_state, '', "Town is not in revolt" );
    is( $town->gold,          0,  "Town's gold is 0 - no tax collected" );
}

sub test_gain_xp : Tests(3) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, mayor_rating => 50 );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town->id, party_id => $party->id );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    $self->{roll_result} = 10;

    my $skill = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Charisma',
        }
    );

    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id     => $skill->id,
            character_id => $mayor->id,
            level        => 10,
        }
    );

    # WHEN
    $action->gain_xp( $town, $mayor );

    # THEN
    is( $mayor->xp, 47, "Mayor has gained xp" );

    my @messages = $town->history;
    is( scalar @messages, 1, "Town has 1 message" );
    like( $messages[0]->message, qr{test gained 47 xp from being mayor}, "Town message has correct text" );
}

sub test_check_for_revolt_party_over_mayor_limit : Tests(5) {
    my $self = shift;

    # GIVEN
    my $town1 = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, mayor_rating => 50 );
    my $town2 = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, mayor_rating => 50 );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, level => 15 );
    my $mayor1 = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town1->id, party_id => $party->id, level => 15 );
    my $mayor2 = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town2->id, party_id => $party->id, level => 15 );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->check_for_revolt($town1);

    # THEN
    $town1->discard_changes;
    is( $town1->peasant_state, 'revolt', "Town now in revolt" );

    my @history = $town1->history;
    is( scalar @history, 1, "One message added to town's history" );
    is( $history[0]->message, "The peasants have had enough of being treated poorly, and revolt against the mayor!", "Correct history message" );

    my @messages = $party->messages;
    is( scalar @messages, 1, "One message added to party's history" );
    is( $messages[0]->message, "test sends word that the peasants of Test Town have risen up in open rebellion against the mayor", "Correct party message" );

}

sub test_check_for_revolt_party_over_mayor_limit_but_one_town_already_revolting : Tests(3) {
    my $self = shift;

    # GIVEN
    my $town1 = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, mayor_rating => 50 );
    my $town2 = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, mayor_rating => 50, peasant_state => 'revolt' );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, level => 15 );
    my $mayor1 = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town1->id, party_id => $party->id, level => 15 );
    my $mayor2 = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town2->id, party_id => $party->id, level => 15 );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->check_for_revolt($town1);

    # THEN
    $town1->discard_changes;
    is( $town1->peasant_state, '', "Town not put into revolt" );

    my @history = $town1->history;
    is( scalar @history, 0, "No message added to town's history" );

    my @messages = $party->messages;
    is( scalar @messages, 0, "No message added to party's history" );
}

sub test_alert_parties_about_exceeding_mayor_limit : Tests(4) {
    my $self = shift;

    # GIVEN
    my $town1 = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, mayor_rating => 50 );
    my $town2 = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, mayor_rating => 50 );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, level => 15 );
    my $mayor1 = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town1->id, party_id => $party->id, level => 15 );
    my $mayor2 = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town2->id, party_id => $party->id, level => 15 );

    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, level => 15 );
    my $town3 = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, mayor_rating => 50 );
    my $mayor3 = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town2->id, party_id => $party2->id, level => 15 );

    my $party3 = Test::RPG::Builder::Party->build_party( $self->{schema} );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->alert_parties_about_exceeding_mayor_limit;

    # THEN
    my @messages = $party->messages;
    is( scalar @messages, 1, "Party 1 given 1 message" );
    is( $messages[0]->message, "We have 2 mayors, which exceeds our maximum of 1. We should relinquish " .
          "the mayoralties of some of our towns, or risk revolts!", "Correct message text" );

    my @messages2 = $party2->messages;
    is( scalar @messages2, 0, "Party 2 not given a message" );

    my @messages3 = $party3->messages;
    is( scalar @messages3, 0, "Party 3 not given a message" );

}

sub test_check_if_election_needed_warning_given_to_party : Tests(2) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, last_election => 88 );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town->id, party_id => $party->id );

    $self->{dont_create_today} = 1;

    my $today = Test::RPG::Builder::Day->build_day( $self->{schema}, day_number => 100 );

    $self->{mock_context}->set_always( 'current_day', $today );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->check_if_election_needed($town);

    # THEN
    my @messages = $party->messages;
    is( scalar @messages, 1, "1 message created for party" );
    is( $messages[0]->message, "The town of Test Town hasn't had an election for 12 days. The towns people expect one soon!",
        "Correct message" );
}

sub test_check_if_election_needed_overdue : Tests(5) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, last_election => 85, mayor_rating => 30 );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town->id, party_id => $party->id );

    $self->{dont_create_today} = 1;

    my $today = Test::RPG::Builder::Day->build_day( $self->{schema}, day_number => 100 );

    $self->{mock_context}->set_always( 'current_day', $today );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );

    # WHEN
    $action->check_if_election_needed($town);

    # THEN
    $town->discard_changes;
    is( $town->mayor_rating, 10, "Mayor's rating reduced" );

    my @history = $town->history;
    is( scalar @history, 1, "1 Messaged added to town's history" );
    is( $history[0]->message, "There hasn't been an election in 15 days! The peasants demand their right to vote be honoured",
        "Correct history message" );

    my @messages = $party->messages;
    is( scalar @messages, 1, "1 message created for party" );
    is( $messages[0]->message, "The town of Test Town hasn't had an election for 15 days. The towns people are extremely upset that one hasn't been called!",
        "Correct message" );
}

1;
