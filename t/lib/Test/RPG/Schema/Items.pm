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
    
    $self->mock_dice;
    
    use_ok('RPG::Schema::Items');
}

sub setup_data : Tests(setup) {
    my $self = shift;
    
    $self->mock_dice;    
    
    $self->{rolls} = [5, 2];

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
        or diag("Actual value: " . $val1->item_variable_value . " (expected in range 1 - 10)");
    is( $val1->max_value, undef, "Max value not set for var1" );

    my $val2 = $self->{item}->variable_row('Var2');
    ok( $val2->item_variable_value >= 5 && $val2->item_variable_value <= 8, "Var2 in correct range" );
    is( $val2->max_value, $val2->item_variable_value, "Max value set for var2" );

    my $val1_value = $self->{item}->variable('Var1');
    ok( $val1_value >= 1 && $val1_value <= 10, "Got variable value directly" );

}

sub test_basic_equip_item : Tests(3) {
    my $self = shift;
    
    my $item = $self->{item};
    
    my @slots_changed = $item->equip_item($self->{equip_place}->equip_place_name);
    
    is(scalar @slots_changed, 1, "one slot changed");
    is($slots_changed[0],  $self->{equip_place}->equip_place_name, "Only the slot were equipping has changed");
    is($item->equip_place_id, $self->{equip_place}->equip_place_id, "Item has been moved into equip place");
}

sub test_equip_item_with_bad_equip_place : Tests(2) {
    my $self = shift;
    
    my $item = $self->{item};
    
    throws_ok(
        sub { $item->equip_item($self->{equip_place_with_no_categories}->equip_place_name) },
        qr|Can't equip an item of that type there|,
        "Throws an exception if equip slot is invalid for this item",
    );    

    is($item->equip_place_id, undef, "Item has not been moved into equip place");
}

sub test_equip_item_with_non_exististant_equip_place : Tests(2) {
    my $self = shift;
    
    my $item = $self->{item};
    
    throws_ok(
        sub { $item->equip_item("foobarfoo") },
        qr|Can't equip an item of that type there|,
        "Throws an exception if equip slot is invalid for this item",
    );    

    is($item->equip_place_id, undef, "Item has not been moved into equip place");   
}

sub test_repair_cost_basic : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        variables => [
            {
                item_variable_name => 'Durability',
                item_variable_value  => 5,
                max_value => 10,
            }
        ],
        base_cost => 100,
    );
    
    my $town = Test::RPG::Builder::Town->build_town($self->{schema});
    $town->blacksmith_skill(10);
    $town->update;
    
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 2);
    $item->character_id(($party->characters)[0]->id);
    $item->update;
    
    # WHEN
    my $repair_cost = $item->repair_cost($town);
    
    # THEN
    is($repair_cost, 11, "Repair cost correct");
}

sub test_repair_cost_with_discount : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        variables => [
            {
                item_variable_name => 'Durability',
                item_variable_value  => 5,
                max_value => 10,
            }
        ],
        base_cost => 100,
    );
    
    my $town = Test::RPG::Builder::Town->build_town($self->{schema});
    $town->discount_type('blacksmith');
    $town->discount_threshold(10);
    $town->discount_value(30);
    $town->blacksmith_skill(5);
    $town->update;
    
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 2);
    $item->character_id(($party->characters)[0]->id);
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
    is($repair_cost, 8, "Repair cost correct");
}

sub test_usable_actions_with_one_usable_enchantment : Tests(2) {
	my $self = shift;
	
	# GIVEN
	$self->unmock_dice();
	
	my $item_type = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema}, enchantments => ['spell_casts_per_day', 'indestructible'] );
	my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, enchantments => ['spell_casts_per_day', 'indestructible'], 
		item_type_id => $item_type->id );
	my ($enchantment) = $item->item_enchantments;
	$enchantment->variable('Spell', 'Heal');
	
	# WHEN
	my @actions = $item->usable_actions;
	
	# THEN
	is(scalar @actions, 1, "Item has one usable action");
	is($actions[0]->enchantment->enchantment_name, 'spell_casts_per_day', "correct action is usable");			
}

sub test_usable_actions_with_no_usable_enchantments : Tests(1) {
	my $self = shift;
	
	# GIVEN	
	$self->unmock_dice();
	
	my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, enchantments => ['indestructible'] );
	
	# WHEN
	my @actions = $item->usable_actions;
	
	# THEN
	is(scalar @actions, 0, "Item has no usable actions");			
}

sub test_sell_price : Tests(2) {
	my $self = shift;
	
	# GIVEN
	$self->unmock_dice();
	
	my $item_type = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema}, base_cost => 20 );
	my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, item_type_id => $item_type->id );
	
	# WHEN
	my $sell_price = $item->sell_price(undef, 0);
	my $sell_price_modified = $item->sell_price(undef, 1);
	
	# THEN
	is($sell_price, 20, "Correct sell price returned");
	is($sell_price_modified, 16, "Correct modified sell price returned");
		
}

sub test_sell_price_enchanted : Tests(2) {
	my $self = shift;
	
	# GIVEN
	$self->unmock_dice();
	
	my $item_type = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema}, base_cost => 20 );
	my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, item_type_id => $item_type->id, enchantments => ['indestructible'] );
	
	# WHEN
	my $sell_price = $item->sell_price(undef, 0);
	my $sell_price_modified = $item->sell_price(undef, 1);
	
	# THEN
	is($sell_price, 145, "Correct sell price returned");
	is($sell_price_modified, 116, "Correct modified sell price returned");
		
}

sub test_adding_item_updates_encumbrance : Tests(2) {
	my $self = shift;
	
	# GIVEN
    my $item = Test::RPG::Builder::Item->build_item($self->{schema});
    my $character = Test::RPG::Builder::Character->build_character($self->{schema});
    
    # WHEN
    $item->character_id($character->id);
    $item->update;
    
    # THEN
    is($character->encumbrance, 0, "Correct encumbrance before update");
    $character->discard_changes;
    is($character->encumbrance, 100, "Item's weight added to character's encumbrance");
}

sub test_removing_item_updates_encumbrance : Tests(2) {
	my $self = shift;
	
	# GIVEN
    my $character = Test::RPG::Builder::Character->build_character($self->{schema});
    my $item = Test::RPG::Builder::Item->build_item($self->{schema}, char_id => $character->id);
    $character->discard_changes;
    
    # WHEN
    $item->character_id(undef);
    $item->update;
    
    # THEN
    is($character->encumbrance, 100, "Correct encumbrance before update");
    $character->discard_changes;
    is($character->encumbrance, 0, "Item's weight removed to character's encumbrance");
}

sub test_swapping_item_updates_encumbrance : Tests(4) {
	my $self = shift;
	
	# GIVEN
    my $character1 = Test::RPG::Builder::Character->build_character($self->{schema});
    my $item = Test::RPG::Builder::Item->build_item($self->{schema}, char_id => $character1->id);
    $character1->discard_changes;    
    my $character2 = Test::RPG::Builder::Character->build_character($self->{schema});
    
    # WHEN
    $item->character_id($character2->id);
    $item->update;
    
    # THEN
    is($character1->encumbrance, 100, "Char1: Correct encumbrance before update");
    $character1->discard_changes;
    is($character1->encumbrance, 0, "Char1: Item's weight removed to character's encumbrance");

    is($character2->encumbrance, 0, "Char2: Correct encumbrance before update");
    $character2->discard_changes;
    is($character2->encumbrance, 100, "Char2: Item's weight added to character's encumbrance");
}

sub test_deleting_item_updates_encumbrance : Tests(2) {
	my $self = shift;
	
	# GIVEN
    my $character = Test::RPG::Builder::Character->build_character($self->{schema});
    my $item = Test::RPG::Builder::Item->build_item($self->{schema}, char_id => $character->id);
    $character->discard_changes;
    
    # WHEN
    $item->delete;
    
    # THEN
    is($character->encumbrance, 100, "Correct encumbrance before update");
    $character->discard_changes;
    is($character->encumbrance, 0, "Item's weight removed to character's encumbrance");
}

sub test_updating_via_method_item_updates_encumbrance : Tests(2) {
	my $self = shift;
	
	# GIVEN
    my $character = Test::RPG::Builder::Character->build_character($self->{schema});
    my $item = Test::RPG::Builder::Item->build_item($self->{schema}, char_id => $character->id);
    $character->discard_changes;
    
    # WHEN
    $item->update({character_id => undef});
    
    # THEN
    is($character->encumbrance, 100, "Correct encumbrance before update");
    $character->discard_changes;
    is($character->encumbrance, 0, "Item's weight removed to character's encumbrance");
}

1;
