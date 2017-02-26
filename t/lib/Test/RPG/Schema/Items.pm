use strict;
use warnings;

package Test::RPG::Schema::Items;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;
use Test::Exception;

use Test::RPG::Builder::Item;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Item_Type;
use Test::RPG::Builder::Character;

sub startup : Tests(startup=>1) {
    my $self = shift;

    use_ok('RPG::Schema::Items');
}

sub setup_data : Tests(setup) {
    my $self = shift;

    $self->mock_dice;

    $self->{rolls} = [ 5, 2 ];
    $self->{roll_result} = 2;

    $self->{item_category} = $self->{schema}->resultset('Item_Category')->create( {} );

    $self->{item_attribute_name} = $self->{schema}->resultset('Item_Attribute_Name')->create(
        {
            item_attribute_name => 'Test1',
            item_category_id    => $self->{item_category}->id,
        }
    );

    $self->{item_type} = $self->{schema}->resultset('Item_Type')->create(
        {
            item_type        => 'Test1',
            item_category_id => $self->{item_category}->id,
        }
    );

    $self->{item_attribute} = $self->{schema}->resultset('Item_Attribute')->create(
        {
            item_attribute_name_id => $self->{item_attribute_name}->id,
            item_attribute_value   => 99,
            item_type_id           => $self->{item_type}->id,
        }
    );

    $self->{item_variable_name_1} = $self->{schema}->resultset('Item_Variable_Name')->create(
        {
            item_variable_name => 'Var1',
            item_category_id   => $self->{item_category}->id,
        }
    );

    $self->{item_variable_name_2} = $self->{schema}->resultset('Item_Variable_Name')->create(
        {
            item_variable_name => 'Var2',
            item_category_id   => $self->{item_category}->id,
        }
    );

    $self->{item_variable_param_1} = $self->{schema}->resultset('Item_Variable_Params')->create(
        {
            item_type_id          => $self->{item_type}->id,
            min_value             => 1,
            max_value             => 10,
            keep_max              => 0,
            item_variable_name_id => $self->{item_variable_name_1}->id,
        }
    );

    $self->{item_variable_param_2} = $self->{schema}->resultset('Item_Variable_Params')->create(
        {
            item_type_id          => $self->{item_type}->id,
            min_value             => 5,
            max_value             => 8,
            keep_max              => 1,
            item_variable_name_id => $self->{item_variable_name_2}->id,
        }
    );

    $self->{item} = $self->{schema}->resultset('Items')->create( { item_type_id => $self->{item_type}->id, } );

    $self->{equip_place} = $self->{schema}->resultset('Equip_Places')->create( { equip_place_name => 'foo', } );

    $self->{equip_place_category} = $self->{schema}->resultset('Equip_Place_Category')->create(
        {
            equip_place_id   => $self->{equip_place}->id,
            item_category_id => $self->{item_category}->id,
        }
    );

    $self->{equip_place_with_no_categories} = $self->{schema}->resultset('Equip_Places')->create( { equip_place_name => 'foo2', } );
}

sub test_attribute : Tests(1) {
    my $self = shift;

    is( $self->{item}->attribute('Test1')->item_attribute_value, 99, "Item attribute value returned" );
}

sub test_variable_params_created : Tests(5) {
    my $self = shift;

    my @item_variables = $self->{item}->item_variables;

    my $val1 = $self->{item}->variable_row('Var1');
    ok( $val1->item_variable_value >= 1 && $val1->item_variable_value <= 10, "Var1 in correct range" )
      or diag( "Actual value: " . $val1->item_variable_value . " (expected in range 1 - 10)" );
    is( $val1->max_value, undef, "Max value not set for var1" );

    my $val2 = $self->{item}->variable_row('Var2');
    ok( $val2->item_variable_value >= 5 && $val2->item_variable_value <= 8, "Var2 in correct range" );
    is( $val2->max_value, $val2->item_variable_value, "Max value set for var2" );

    my $val1_value = $self->{item}->variable('Var1');
    ok( $val1_value >= 1 && $val1_value <= 10, "Got variable value directly" );

}

sub test_basic_equip_item : Tests(2) {
    my $self = shift;

    my $item = $self->{item};
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    $character->create_item_grid;
    $item->character_id( $character->id );
    $item->update;

    my @extra_items_removed = $item->equip_item( $self->{equip_place}->equip_place_name );

    is( scalar @extra_items_removed, 0, "no extra items removed" );
    is( $item->equip_place_id, $self->{equip_place}->equip_place_id, "Item has been moved into equip place" );
}

sub test_equip_item_with_bad_equip_place : Tests(2) {
    my $self = shift;

    my $item = $self->{item};

    throws_ok(
        sub { $item->equip_item( $self->{equip_place_with_no_categories}->equip_place_name ) },
        qr|Can't equip an item of that type there|,
        "Throws an exception if equip slot is invalid for this item",
    );

    is( $item->equip_place_id, undef, "Item has not been moved into equip place" );
}

sub test_equip_item_with_non_exististant_equip_place : Tests(2) {
    my $self = shift;

    my $item = $self->{item};

    throws_ok(
        sub { $item->equip_item("foobarfoo") },
        qr|Can't equip an item of that type there|,
        "Throws an exception if equip slot is invalid for this item",
    );

    is( $item->equip_place_id, undef, "Item has not been moved into equip place" );
}

sub test_basic_equip_not_replacing_existing_item : Tests(8) {
    my $self = shift;

    # GIVEN
    my $item1 = $self->{item};
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    $character->create_item_grid;
    $item1->character_id( $character->id );
    $item1->update;

    my $item2 = $self->{schema}->resultset('Items')->create( { item_type_id => $self->{item_type}->id, } );
    $item2->character_id( $character->id );
    $item2->update;

    $character->add_item_to_grid($item1);
    $character->add_item_to_grid($item2);

    # WHEN
    my @extra_items_removed_first_equip = $item1->equip_item( $self->{equip_place}->equip_place_name );

    # THEN
    is( scalar @extra_items_removed_first_equip, 0, "no extra items removed in first equip" );
    is( $item1->equip_place_id, $self->{equip_place}->equip_place_id, "Item1 has been moved into equip place" );
    is( $item1->grid_sectors->count, 0, "Item 1 not in item grid" );
    is( $item2->grid_sectors->count, 1, "Item 2 is in item grid" );

    # WHEN 2
    my @extra_items_removed_second_equip = $item2->equip_item( $self->{equip_place}->equip_place_name, replace_existing_equipment => 0 );

    # THEN 2
    is( scalar @extra_items_removed_second_equip, 0, "no extra items removed in second equip" );
    is( $item2->equip_place_id,      undef, "Item2 was not equipped" );
    is( $item1->grid_sectors->count, 0,     "Item 1 still not in item grid" );
    is( $item2->grid_sectors->count, 1,     "Item 2 still in item grid" );
}

sub test_repair_cost_basic : Tests(1) {
    my $self = shift;

    # GIVEN
    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        variables => [
            {
                item_variable_name  => 'Durability',
                item_variable_value => 5,
                max_value           => 10,
            }
        ],
        base_cost => 100,
    );

    my $town = Test::RPG::Builder::Town->build_town( $self->{schema} );
    $town->blacksmith_skill(10);
    $town->update;

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    $item->character_id( ( $party->characters )[0]->id );
    $item->update;

    # WHEN
    my $repair_cost = $item->repair_cost($town);

    # THEN
    is( $repair_cost, 11, "Repair cost correct" );
}

sub test_repair_cost_with_discount : Tests(1) {
    my $self = shift;

    # GIVEN
    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        variables => [
            {
                item_variable_name  => 'Durability',
                item_variable_value => 5,
                max_value           => 10,
            }
        ],
        base_cost => 100,
    );

    my $town = Test::RPG::Builder::Town->build_town( $self->{schema} );
    $town->discount_type('blacksmith');
    $town->discount_threshold(10);
    $town->discount_value(30);
    $town->blacksmith_skill(5);
    $town->update;

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    $item->character_id( ( $party->characters )[0]->id );
    $item->update;

    my $party_town = $self->{schema}->resultset('Party_Town')->find_or_create(
        {
            party_id => $party->id,
            town_id  => $town->id,
            prestige => 10,
        },
    );

    $self->{config}{min_repair_cost} = 1;
    $self->{config}{max_repair_cost} = 6;

    # WHEN
    my $repair_cost = $item->repair_cost($town);

    # THEN
    is( $repair_cost, 8, "Repair cost correct" );
}

sub test_usable_actions_with_one_usable_enchantment : Tests(2) {
    my $self = shift;

    # GIVEN
    $self->unmock_dice();

    my $item_type = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema}, enchantments => [ 'spell_casts_per_day', 'indestructible' ] );
    my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, enchantments => [ 'spell_casts_per_day', 'indestructible' ],
        item_type_id => $item_type->id );
    my ($enchantment) = $item->item_enchantments;
    $enchantment->variable( 'Spell', 'Heal' );

    # WHEN
    my @actions = $item->usable_actions;

    # THEN
    is( scalar @actions, 1, "Item has one usable action" );
    is( $actions[0]->enchantment->enchantment_name, 'spell_casts_per_day', "correct action is usable" );
}

sub test_usable_actions_with_no_usable_enchantments : Tests(1) {
    my $self = shift;

    # GIVEN
    $self->unmock_dice();

    my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, enchantments => ['indestructible'] );

    # WHEN
    my @actions = $item->usable_actions;

    # THEN
    is( scalar @actions, 0, "Item has no usable actions" );
}

sub test_usable_actions_with_usable_item_no_character : Tests(1) {
    my $self = shift;

    # GIVEN
    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        item_type_name => 'Potion of Healing',
        usable         => 1,
        variables      => [
            {
                item_variable_name  => 'Quantity',
                item_variable_value => 1,
            }
        ],
    );

    # WHEN
    my @actions = $item->usable_actions;

    # THEN
    is( scalar @actions, 0, "Item not usable as doesn't belong to a character" );
}

sub test_usable_actions_with_usable_item : Tests(2) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 9, max_hit_points => 10 );
    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        item_type_name => 'Potion of Healing',
        usable         => 1,
        variables      => [
            {
                item_variable_name  => 'Quantity',
                item_variable_value => 1,
            }
        ],
        character_id => $character->id,
    );

    # WHEN
    my @actions = $item->usable_actions;

    # THEN
    is( scalar @actions, 1,         "Item is usable" );
    is( $actions[0]->id, $item->id, "Correct item returned" );
}

sub test_sell_price : Tests(2) {
    my $self = shift;

    # GIVEN
    $self->unmock_dice();

    my $item_type = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema}, base_cost => 20 );
    my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, item_type_id => $item_type->id );

    # WHEN
    my $sell_price          = $item->sell_price( undef, 0 );
    my $sell_price_modified = $item->sell_price( undef, 1 );

    # THEN
    is( $sell_price,          20, "Correct sell price returned" );
    is( $sell_price_modified, 16, "Correct modified sell price returned" );

}

sub test_sell_price_enchanted : Tests(2) {
    my $self = shift;

    # GIVEN
    $self->unmock_dice();

    my $item_type = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema}, base_cost => 20 );
    my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, item_type_id => $item_type->id, enchantments => ['indestructible'] );

    # WHEN
    my $sell_price          = $item->sell_price( undef, 0 );
    my $sell_price_modified = $item->sell_price( undef, 1 );

    # THEN
    is( $sell_price,          740, "Correct sell price returned" );
    is( $sell_price_modified, 592, "Correct modified sell price returned" );

}

sub test_adding_item_updates_encumbrance : Tests(2) {
    my $self = shift;

    # GIVEN
    my $item = Test::RPG::Builder::Item->build_item( $self->{schema} );
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );

    # WHEN
    $item->character_id( $character->id );
    $item->update;

    # THEN
    is( $character->encumbrance, 0, "Correct encumbrance before update" );
    $character->discard_changes;
    is( $character->encumbrance, 100, "Item's weight added to character's encumbrance" );
}

sub test_removing_item_updates_encumbrance : Tests(2) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $character->id );
    $character->discard_changes;

    # WHEN
    $item->character_id(undef);
    $item->update;

    # THEN
    is( $character->encumbrance, 100, "Correct encumbrance before update" );
    $character->discard_changes;
    is( $character->encumbrance, 0, "Item's weight removed to character's encumbrance" );
}

sub test_swapping_item_updates_encumbrance : Tests(4) {
    my $self = shift;

    # GIVEN
    my $character1 = Test::RPG::Builder::Character->build_character( $self->{schema} );
    my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $character1->id );
    $character1->discard_changes;
    my $character2 = Test::RPG::Builder::Character->build_character( $self->{schema} );

    # WHEN
    $item->character_id( $character2->id );
    $item->update;

    # THEN
    is( $character1->encumbrance, 100, "Char1: Correct encumbrance before update" );
    $character1->discard_changes;
    is( $character1->encumbrance, 0, "Char1: Item's weight removed to character's encumbrance" );

    is( $character2->encumbrance, 0, "Char2: Correct encumbrance before update" );
    $character2->discard_changes;
    is( $character2->encumbrance, 100, "Char2: Item's weight added to character's encumbrance" );
}

sub test_deleting_item_updates_encumbrance : Tests(2) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $character->id );
    $character->discard_changes;

    # WHEN
    $item->delete;

    # THEN
    is( $character->encumbrance, 100, "Correct encumbrance before update" );
    $character->discard_changes;
    is( $character->encumbrance, 0, "Item's weight removed to character's encumbrance" );
}

sub test_updating_via_method_item_updates_encumbrance : Tests(2) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $character->id );
    $character->discard_changes;

    # WHEN
    $item->update( { character_id => undef } );

    # THEN
    is( $character->encumbrance, 100, "Correct encumbrance before update" );
    $character->discard_changes;
    is( $character->encumbrance, 0, "Item's weight removed to character's encumbrance" );
}

sub test_equipping_item_updates_stat_bonus_including_af : Tests(2) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, strength => 10 );
    $character->calculate_attack_factor;
    $character->update;

    my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $character->id, enchantments => ['stat_bonus'], no_equip_place => 1 );
    $item->variable( 'Stat Bonus', 'strength' );
    $item->variable( 'Bonus',      2 );
    $item->update;

    # WHEN
    $item->equip_place_id(1);
    $item->update;

    # THEN
    $character->discard_changes;
    is( $character->strength_bonus, 2,  "Stat bonus increased correctly" );
    is( $character->attack_factor,  12, "Attack factor correctly updated" );
}

sub test_equipping_item_updates_stat_bonus_including_df : Tests(2) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, agility => 10 );
    $character->calculate_attack_factor;
    $character->update;

    my $item = Test::RPG::Builder::Item->build_item( $self->{schema},
        char_id        => $character->id,
        enchantments   => ['stat_bonus'],
        no_equip_place => 1,
        attributes     => [
            {
                item_attribute_name  => 'Attack Factor',
                item_attribute_value => 10,
            },
        ],
    );
    $item->variable( 'Stat Bonus', 'agility' );
    $item->variable( 'Bonus',      2 );
    $item->update;

    # WHEN
    $item->equip_place_id(1);
    $item->update;

    # THEN
    $character->discard_changes;
    is( $character->agility_bonus,  2,  "Stat bonus increased correctly" );
    is( $character->defence_factor, 12, "Defence factor correctly updated" );
}

sub test_unequipping_item_updates_stat_bonus : Tests(1) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $character->id, enchantments => ['stat_bonus'], no_equip_place => 1 );
    $item->variable( 'Stat Bonus', 'strength' );
    $item->variable( 'Bonus',      2 );
    $item->equip_place_id(1);
    $item->update;

    # WHEN
    $item->equip_place_id(undef);
    $item->update;

    # THEN
    $character->discard_changes;
    is( $character->strength_bonus, 0, "Stat bonus decreased correctly" );
}

sub test_giving_item_to_char_updates_stat_bonus : Tests(2) {
    my $self = shift;

    # GIVEN
    $self->unmock_dice();

    my $character1 = Test::RPG::Builder::Character->build_character( $self->{schema} );
    my $character2 = Test::RPG::Builder::Character->build_character( $self->{schema} );
    my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $character1->id, enchantments => ['stat_bonus'], no_equip_place => 1 );
    $item->variable( 'Stat Bonus', 'strength' );
    $item->variable( 'Bonus',      2 );
    $item->equip_place_id(1);
    $item->update;

    # WHEN
    $item->character_id( $character2->id );
    $item->update;

    # THEN
    $character1->discard_changes;
    is( $character1->strength_bonus, 0, "Stat bonus decreased for char 1 correctly" );
    $character2->discard_changes;
    is( $character2->strength_bonus, 0, "Stat bonus not increased for char 2" );
}

sub test_setting_equip_place_id_to_null_against_doesnt_decrease_stat_bonus : Tests(1) {
    my $self = shift;

    # GIVEN
    $self->unmock_dice();

    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $character->id, enchantments => ['stat_bonus'], no_equip_place => 1 );
    $item->variable( 'Stat Bonus', 'strength' );
    $item->variable( 'Bonus',      2 );
    $item->update;

    # WHEN
    $item->equip_place_id(undef);
    $item->update;

    # THEN
    $character->discard_changes;
    is( $character->strength_bonus, 0, "Stat bonus still 0 for character" );
}

sub test_clearning_char_id_and_equip_place_works_correctly : Tests(2) {
    my $self = shift;

    # GIVEN
    $self->unmock_dice();

    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $character->id, enchantments => ['stat_bonus'] );
    $item->variable( 'Stat Bonus', 'strength' );
    $item->variable( 'Bonus',      2 );
    $item->update;

    # WHEN
    $item->character_id(undef);

    #$item->equip_place_id(undef);
    $item->update;

    # THEN
    $item->discard_changes;
    is( $item->character_id,   undef, "Character id cleared correctly" );
    is( $item->equip_place_id, undef, "Equip place id cleared correctly" );
}

sub test_equipping_item_updates_stat_bonus_multiple : Tests(2) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $character->id, enchantments => [ 'stat_bonus', 'stat_bonus' ], no_equip_place => 1 );

    my @enchantments = $item->item_enchantments;
    $enchantments[0]->variable( 'Stat Bonus', 'strength' );
    $enchantments[0]->variable( 'Bonus',      2 );
    $enchantments[0]->update;

    $enchantments[1]->variable( 'Stat Bonus', 'agility' );
    $enchantments[1]->variable( 'Bonus',      3 );
    $enchantments[1]->update;

    # WHEN
    $item->equip_place_id(1);
    $item->update;

    # THEN
    $character->discard_changes;
    is( $character->strength_bonus, 2, "Stat bonus 1 increased correctly" );
    is( $character->agility_bonus,  3, "Stat bonus 2 increased correctly" );
}

sub test_unequipping_item_updates_stat_bonus_multiple : Tests(2) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $character->id, enchantments => [ 'stat_bonus', 'stat_bonus' ], no_equip_place => 1 );

    my @enchantments = $item->item_enchantments;
    $enchantments[0]->variable( 'Stat Bonus', 'strength' );
    $enchantments[0]->variable( 'Bonus',      2 );
    $enchantments[0]->update;

    $enchantments[1]->variable( 'Stat Bonus', 'agility' );
    $enchantments[1]->variable( 'Bonus',      3 );
    $enchantments[1]->update;

    $item->equip_place_id(1);
    $item->update;

    # WHEN
    $item->equip_place_id(undef);
    $item->update;

    # THEN
    $character->discard_changes;
    is( $character->strength_bonus, 0, "Stat bonus 1 decreased correctly" );
    is( $character->agility_bonus,  0, "Stat bonus 2 decreased correctly" );
}

sub test_equipping_item_updates_defence_factor : Tests(1) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, agility => 10 );
    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $character->id,
        super_category_name => 'Armour',
        category_name       => 'Armour',
        no_equip_place      => 1,
        variables           => [
            {
                item_variable_name  => 'Defence Factor Upgrade',
                item_variable_value => 3,
            },
        ],
        attributes => [
            {
                item_attribute_name  => 'Defence Factor',
                item_attribute_value => 2,
            }
        ],
    );

    # WHEN
    $item->equip_place_id(1);
    $item->update;

    # THEN
    $character->discard_changes;
    is( $character->defence_factor, 15, "Defence factor increased correctly" );
}

sub test_unequipping_item_updates_defence_factor : Tests(2) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, agility => 10 );
    my $item1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $character->id,
        super_category_name => 'Armour',
        category_name       => 'Armour',
        no_equip_place      => 1,
        attributes          => [
            {
                item_attribute_name  => 'Defence Factor',
                item_attribute_value => 2,
            }
        ],
    );
    $item1->equip_place_id(1);
    $item1->update;

    # WHEN
    $character->discard_changes;
    my $init_df = $character->defence_factor;

    $item1->equip_place_id(undef);
    $item1->update;

    $character->discard_changes;

    # THEN
    is( $init_df, 12, "Correct initial defence factor" );

    is( $character->defence_factor, 10, "Defence factor reduced correctly" );
}

sub test_unequipping_item_updates_defence_factor_existing_item : Tests(2) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, agility => 10 );
    my $item1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $character->id,
        super_category_name => 'Armour',
        category_name       => 'Armour',
        no_equip_place      => 1,
        variables           => [
            {
                item_variable_name  => 'Defence Factor Upgrade',
                item_variable_value => 3,
            },
        ],
        attributes => [
            {
                item_attribute_name  => 'Defence Factor',
                item_attribute_value => 2,
            }
        ],
    );
    $item1->equip_place_id(1);
    $item1->update;

    my $item2 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $character->id,
        super_category_name => 'Armour',
        category_name       => 'Head Gear',
        no_equip_place      => 1,
        attributes          => [
            {
                item_attribute_name  => 'Defence Factor',
                item_attribute_value => 5,
            }
        ],
    );
    $item2->equip_place_id(2);
    $item2->update;

    # WHEN
    $character->discard_changes;
    my $init_df = $character->defence_factor;

    $item1->equip_place_id(undef);
    $item1->update;

    $character->discard_changes;

    # THEN
    is( $init_df, 20, "Correct initial defence factor" );

    is( $character->defence_factor, 15, "Defence factor reduced correctly" );
}

sub test_equipping_item_updates_attack_factor : Tests(1) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, strength => 10 );
    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $character->id,
        super_category_name => 'Weapon',
        category_name       => 'Melee Weapon',
        no_equip_place      => 1,
        variables           => [
            {
                item_variable_name  => 'Attack Factor Upgrade',
                item_variable_value => 3,
            },
        ],
        attributes => [
            {
                item_attribute_name  => 'Attack Factor',
                item_attribute_value => 2,
            }
        ],
    );

    # WHEN
    $item->equip_place_id(1);
    $item->update;

    # THEN
    $character->discard_changes;
    is( $character->attack_factor, 15, "Attack factor increased correctly" );
}

sub test_unequipping_item_updates_attack_factor : Tests(2) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, agility => 10 );
    my $item1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $character->id,
        super_category_name => 'Weapon',
        category_name       => 'Ranged Weapon',
        no_equip_place      => 1,
        attributes          => [
            {
                item_attribute_name  => 'Attack Factor',
                item_attribute_value => 3,
            }
        ],
    );
    $item1->equip_place_id(1);
    $item1->update;

    # WHEN
    $character->discard_changes;
    my $init_af = $character->attack_factor;

    $item1->equip_place_id(undef);
    $item1->update;

    $character->discard_changes;

    # THEN
    is( $init_af, 13, "Correct initial attack factor" );

    is( $character->attack_factor, 10, "Attack factor reduced correctly" );
}

sub test_equipping_item_updates_movement_factor_bonus : Tests(2) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, constitution => 12 );
    $character->calculate_attack_factor;
    $character->update;

    my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $character->id, enchantments => ['movement_bonus'], no_equip_place => 1 );
    $item->variable( 'Movement Bonus', '2' );
    $item->update;

    # WHEN
    $item->equip_place_id(1);
    $item->update;

    # THEN
    $character->discard_changes;
    is( $character->movement_factor_bonus, 2, "Movement factor bonus increased correctly" );
    is( $character->natural_movement_factor, 5, "Movement factor correct" );
}

sub test_equipping_item_updates_with_con_bonus_updates_movement_factor : Tests(1) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, constitution => 12 );
    $character->calculate_attack_factor;
    $character->update;

    my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $character->id, enchantments => ['stat_bonus'], no_equip_place => 1 );
    $item->variable( 'Stat Bonus', 'constitution' );
    $item->variable( 'Bonus',      4 );
    $item->update;

    # WHEN
    $item->equip_place_id(1);
    $item->update;

    # THEN
    $character->discard_changes;
    is( $character->natural_movement_factor, 4, "Movement factor correct" );
}

sub test_add_to_characters_inventory_stacking : Tests(2) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );

    my $item1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        variables => [
            {
                item_variable_name  => 'Quantity',
                item_variable_value => 5,
            }
        ],
        character_id => $character->id,
    );

    my $item2 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        variables => [
            {
                item_variable_name  => 'Quantity',
                item_variable_value => 5,
            }
        ],
    );

    $item2->item_type_id( $item1->item_type_id );
    $item2->update;

    # WHEN
    $item2->add_to_characters_inventory($character);

    # THEN
    is( $item1->variable('Quantity'), 10, "Item quantities added together" );

    $item2->discard_changes;
    is( $item2->character_id, undef, "Second item not added to inventory" );

}

sub test_add_to_characters_inventory_not_stacked : Tests(2) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    $character->create_item_grid;

    my $item1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        variables => [
            {
                item_variable_name  => 'Quantity',
                item_variable_value => 5,
            }
        ],
        character_id => $character->id,
    );

    my $item2 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        variables => [
            {
                item_variable_name  => 'Quantity',
                item_variable_value => 5,
            }
        ],
    );

    # WHEN
    $item2->add_to_characters_inventory($character);

    # THEN
    is( $item1->variable('Quantity'), 5, "Item quantities not added together" );

    $item2->discard_changes;
    is( $item2->character_id, $character->id, "Second item added to inventory" );

}

sub test_add_to_characters_inventory_finger : Tests(3) {
    my $self = shift;

    # GIVEN
    my $character1 = Test::RPG::Builder::Character->build_character( $self->{schema} );
    my $character2 = Test::RPG::Builder::Character->build_character( $self->{schema}, strength => 10 );
    $character2->create_item_grid;

    my $item_type = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema},
        category_name => 'Ring',
        equip_places_allowed => [ 'Left Ring Finger', 'Right Ring Finger' ],
    );

    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        item_type_id => $item_type->id,
        enchantments => ['stat_bonus'],
        character_id => $character1->id,
    );
    $item->variable( 'Stat Bonus', 'strength' );
    $item->variable( 'Bonus',      2 );
    $item->update;

    # WHEN
    $item->add_to_characters_inventory($character2);

    # THEN
    is( $item->character_id, $character2->id, "Item added to inventory" );
    ok( $item->equip_place_id == 5 || $item->equip_place_id == 6, "Item equipped in correct place" );

    $character2->discard_changes;
    is( $character2->strength, 12, "Character's strength increased" );
}

sub equip_item_finger_swap : Tests(3) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, strength => 10 );
    $character->create_item_grid;

    my $item_type = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema},
        category_name => 'Ring',
        equip_places_allowed => [ 'Left Ring Finger', 'Right Ring Finger' ],
    );

    my $item1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        item_type_id => $item_type->id,
        enchantments => ['stat_bonus'],
    );
    $item1->variable( 'Stat Bonus', 'strength' );
    $item1->variable( 'Bonus',      2 );
    $item1->update;

    $item1->add_to_characters_inventory( $character, undef, 0 );

    #diag "Item 1: " . $item1->id;

    my $item2 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        item_type_id => $item_type->id,
        enchantments => ['stat_bonus'],
    );
    $item2->variable( 'Stat Bonus', 'strength' );
    $item2->variable( 'Bonus',      2 );
    $item2->update;

    #diag "Item 2: " . $item2->id;

    $item2->add_to_characters_inventory( $character, undef, 0 );

    # WHEN
    # Equip first item
    $item1->equip_item('Left Ring Finger');

    # Equip second item
    $item2->equip_item('Right Ring Finger');

    # Move first into second's slot
    $item1->equip_item( 'Right Ring Finger', existing_item_x => 1, existing_item_y => 1 );

    # THEN
    $item1->discard_changes;

    is( $item1->equip_place_id, 6, "First item equipped in correct slot" );

    $item2->discard_changes;
    is( $item2->equip_place_id, undef, "Second item no longer equipped" );

    $character->discard_changes;
    is( $character->strength, 12, "Character's strength increased" );
}

sub test_role_applied_if_exists : Tests(1) {
    my $self = shift;

    # GIVEN
    my $item_type = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema}, item_type => 'Potion of Healing' );

    # WHEN
    my $item = $self->{schema}->resultset('Items')->create(
        {
            item_type_id => $item_type->id,
        }
    );

    # THEN
    is( $item->can('use') ? 1 : 0, 1, "Role applied to new item" );
}

sub test_created_if_no_role : Tests(1) {
    my $self = shift;

    # GIVEN
    my $item_type = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema}, );

    # WHEN
    my $item = $self->{schema}->resultset('Items')->create(
        {
            item_type_id => $item_type->id,
        }
    );

    # THEN
    is( $item->can('use') ? 1 : 0, 0, "No role applied" );
}

sub test_equipping_usable_items_updates_usable_flags : Tests(6) {
    my $self = shift;

    # GIVEN
    my @tests = (
        {
            spell              => 'Heal',
            combat_actions     => 1,
            non_combat_actions => 1,
        },
        {
            spell              => 'Flame',
            combat_actions     => 1,
            non_combat_actions => 0,
        },
        {
            spell              => 'Farsight',
            combat_actions     => 0,
            non_combat_actions => 1,
        },
    );

    foreach my $test (@tests) {

        my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );

        my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $character->id, enchantments => ['spell_casts_per_day'], no_equip_place => 1 );
        $item->variable( 'Casts Per Day', '2' );
        $item->variable( 'Spell',         $test->{spell} );
        $item->update;

        # WHEN
        $item->equip_place_id(1);
        $item->update;

        # THEN
        $character->discard_changes;
        is( $character->has_usable_actions_combat, $test->{combat_actions}, $test->{spell} . " - Character has correct flag for usable items in combat" );
        is( $character->has_usable_actions_non_combat, $test->{non_combat_actions}, $test->{spell} . " - Character has correct flag for usable items outside combat" );
    }
}

sub test_unequipping_usable_items_updates_usable_flags : Tests(2) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );

    my $item1 = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $character->id, enchantments => ['spell_casts_per_day'], no_equip_place => 1 );
    $item1->variable( 'Casts Per Day', '2' );
    $item1->variable( 'Spell',         'Heal' );
    $item1->equip_place_id(1);
    $item1->update;

    # WHEN
    $item1->equip_place_id(undef);
    $item1->update;

    # THEN
    $character->discard_changes;
    is( $character->has_usable_actions_combat, 0, "Character has correct flag for usable items in combat" );
    is( $character->has_usable_actions_non_combat, 0, "Character has correct flag for usable items outside combat" );

}

sub test_unequipping_usable_items_updates_usable_flags_with_existing_items : Tests(2) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );

    my $item1 = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $character->id, enchantments => ['spell_casts_per_day'], no_equip_place => 1 );
    $item1->variable( 'Casts Per Day', '2' );
    $item1->variable( 'Spell',         'Heal' );
    $item1->equip_place_id(1);
    $item1->update;

    my $item2 = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $character->id, enchantments => ['spell_casts_per_day'], no_equip_place => 1 );
    $item2->variable( 'Casts Per Day', '2' );
    $item2->variable( 'Spell',         'Flame' );
    $item2->equip_place_id(2);
    $item2->update;

    # WHEN
    $item1->equip_place_id(undef);
    $item1->update;

    # THEN
    $character->discard_changes;
    is( $character->has_usable_actions_combat, 1, "Character has correct flag for usable items in combat" );
    is( $character->has_usable_actions_non_combat, 0, "Character has correct flag for usable items outside combat" );
}

sub test_adding_item_updates_usable_flags : Tests(2) {
    my $self = shift;

    # GIVEN
    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        item_type_name => 'Potion of Divinity',
        usable         => 1,
        variables      => [
            {
                item_variable_name  => 'Quantity',
                item_variable_value => 1,
            }
        ],
    );
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 5 );

    # WHEN
    $item->character_id( $character->id );
    $item->update;

    # THEN
    is( $character->has_usable_actions_non_combat, 0, "Correct usable flag before update" );
    $character->discard_changes;
    is( $character->has_usable_actions_non_combat, 1, "Flag updated to when item added to character's inventory" );
}

sub test_adding_item_updates_usable_flags_with_existing_items : Tests(4) {
    my $self = shift;

    # GIVEN
    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        item_type_name => 'Potion of Divinity',
        usable         => 1,
        variables      => [
            {
                item_variable_name  => 'Quantity',
                item_variable_value => 1,
            }
        ],
    );
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 5 );

    my $item2 = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $character->id, enchantments => ['spell_casts_per_day'], no_equip_place => 1 );
    $item2->variable( 'Casts Per Day', '2' );
    $item2->variable( 'Spell',         'Flame' );
    $item2->equip_place_id(2);
    $item2->update;
    $character->discard_changes;

    # WHEN
    $item->character_id( $character->id );
    $item->update;

    # THEN
    is( $character->has_usable_actions_combat, 1, "Correct combat usable flag before update" );
    is( $character->has_usable_actions_non_combat, 0, "Correct usable flag before update" );
    $character->discard_changes;
    is( $character->has_usable_actions_non_combat, 1, "Flag updated to when item added to character's inventory" );
    is( $character->has_usable_actions_combat, 1, "Correct combat usable flag after update" );
}

sub test_removing_item_updates_usable_flags : Tests(2) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 5 );
    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        item_type_name => 'Potion of Divinity',
        usable         => 1,
        variables      => [
            {
                item_variable_name  => 'Quantity',
                item_variable_value => 1,
            }
        ],
    );
    $item->character_id( $character->id );
    $item->update;

    $character->discard_changes;

    # WHEN
    $item->character_id(undef);
    $item->update;

    # THEN
    is( $character->has_usable_actions_non_combat, 1, "Correct usable flag before update" );
    $character->discard_changes;
    is( $character->has_usable_actions_non_combat, 0, "Flag updated to when item added to character's inventory" );
}

sub test_swapping_item_updates_usable_flags : Tests(4) {
    my $self = shift;

    # GIVEN
    my $character1 = Test::RPG::Builder::Character->build_character( $self->{schema} );
    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        item_type_name => 'Potion of Divinity',
        usable         => 1,
        variables      => [
            {
                item_variable_name  => 'Quantity',
                item_variable_value => 1,
            }
        ],
    );
    $item->character_id( $character1->id );
    $item->update;
    $character1->discard_changes;
    my $character2 = Test::RPG::Builder::Character->build_character( $self->{schema} );

    # WHEN
    $item->character_id( $character2->id );
    $item->update;

    # THEN
    is( $character1->has_usable_actions_non_combat, 1, "Correct usable flag before update" );
    $character1->discard_changes;
    is( $character1->has_usable_actions_non_combat, 0, "Flag updated to when item added to character's inventory" );

    is( $character2->has_usable_actions_non_combat, 0, "Correct usable flag before update" );
    $character2->discard_changes;
    is( $character2->has_usable_actions_non_combat, 1, "Flag updated to when item added to character's inventory" );

}

sub test_adding_item_with_reference_to_character_updates_usable_flags : Tests(2) {
    my $self = shift;

    # GIVEN
    # Potion of Healing has references to the character in it's is_usable method.
    #  Because the trigger runs before this is updated in the DB, it has to be
    #  passed in manually. Check this is dealt with
    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        item_type_name => 'Potion of Healing',
        usable         => 1,
        variables      => [
            {
                item_variable_name  => 'Quantity',
                item_variable_value => 1,
            }
        ],
    );
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 5 );

    # WHEN
    $item->character_id( $character->id );
    $item->update;

    # THEN
    is( $character->has_usable_actions_non_combat, 0, "Correct usable flag before update" );
    $character->discard_changes;
    is( $character->has_usable_actions_non_combat, 1, "Flag updated to when item added to character's inventory" );
}

1;
