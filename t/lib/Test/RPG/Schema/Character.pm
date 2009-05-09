use strict;
use warnings;

package Test::RPG::Schema::Character;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Item;

sub character_startup : Tests(startup => 1) {
    my $self = shift;

    $self->{dice} = Test::MockObject->fake_module( 'Games::Dice::Advanced', roll => sub { $self->{roll_result} || 0 }, );

    use_ok('RPG::Schema::Character');
}

sub test_get_equipped_item : Tests(2) {
    my $self = shift;

    my $char = $self->{schema}->resultset('Character')->create(
        {

        }
    );

    my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $char->id, );

    my ($equipped_item) = $char->get_equipped_item('Test1');

    isa_ok( $equipped_item, 'RPG::Schema::Items', "Item record returned" );
    is( $equipped_item->id, $item->id, "Correct item returned" );

}

sub test_get_equipped_item_multiple_items : Tests(2) {
    my $self = shift;

    my $char = $self->{schema}->resultset('Character')->create(
        {

        }
    );

    my $item1 = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $char->id, );
    $item1->equip_place_id(undef);
    $item1->update;
    my $item2 = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $char->id, );

    my ($equipped_item) = $char->get_equipped_item('Test1');

    isa_ok( $equipped_item, 'RPG::Schema::Items', "Item record returned" );
    is( $equipped_item->id, $item2->id, "Correct item returned" );

}

sub test_defence_factor : Tests(1) {
    my $self = shift;

    # Given
    my $char = $self->{schema}->resultset('Character')->create( { agility => 2, } );

    my $item1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Armour',
        variables           => [
            {
                item_variable_name  => 'Durability',
                item_variable_value => 5,
            },
        ],
        attributes => [
            {
                item_attribute_name  => 'Defence Factor',
                item_attribute_value => 3,
            }
        ],
    );

    my $item2 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Armour',
        variables           => [
            {
                item_variable_name  => 'Durability',
                item_variable_value => 0,
            },
        ],
        attributes => [
            {
                item_attribute_name  => 'Defence Factor',
                item_attribute_value => 3,
            }
        ],
    );

    my $item3 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Armour',
        attributes          => [
            {
                item_attribute_name  => 'Defence Factor',
                item_attribute_value => 3,
            }
        ],
    );

    # WHEN
    my $df = $char->defence_factor;

    # THEN
    is( $df, 8, "Includes all equipped armour except the one that's damaged" );
}

sub test_number_of_attacks : Tests(12) {
    my $self = shift;

    my $mock_char = Test::MockObject->new();
    $mock_char->set_always( 'class', $mock_char );
    $mock_char->set_true('class_name');

    $mock_char->set_always( 'effect_value', 0.5 );
    is( RPG::Schema::Character::number_of_attacks( $mock_char, ( 1, 1 ) ), 2, '2 attacks allowed this round because of modifier', );

    is( RPG::Schema::Character::number_of_attacks( $mock_char, ( 1, 2 ) ), 1, '1 attacks allowed this round because of history', );

    $mock_char->set_always( 'effect_value', 0.33 );
    is( RPG::Schema::Character::number_of_attacks( $mock_char, ( 2, 1, 1 ) ), 2, '2 attacks allowed this round because of modifier', );

    is( RPG::Schema::Character::number_of_attacks( $mock_char, ( 2, 1 ) ), 1, '1 attacks allowed this round because of history', );

    $mock_char->set_always( 'effect_value', 1 );
    is( RPG::Schema::Character::number_of_attacks( $mock_char, ( 7, 2 ) ), 2, '2 attacks allowed this round because of modifier', );

    $mock_char->set_always( 'effect_value', 1.5 );
    is( RPG::Schema::Character::number_of_attacks( $mock_char, ( 2, 2 ) ), 3, '3 attacks allowed this round because of modifier', );

    is( RPG::Schema::Character::number_of_attacks( $mock_char, ( 2, 3 ) ), 2, '2 attacks allowed this round because of modifier', );

    $mock_char->set_always( 'effect_value', 1.25 );
    is( RPG::Schema::Character::number_of_attacks( $mock_char, ( 2, 3, 2, 2 ) ), 2, '2 attacks allowed this round because of history', );

    is( RPG::Schema::Character::number_of_attacks( $mock_char, ( 3, 2, 2, 2 ) ), 3, '3 attacks allowed this round because of modifier', );

    # Test archer's extra attacks
    $mock_char->set_always( 'class_name', 'Archer' );
    my $mock_weapon = Test::MockObject->new();
    $mock_weapon->set_always( 'item_type',     $mock_weapon );
    $mock_weapon->set_always( 'category',      $mock_weapon );
    $mock_weapon->set_always( 'item_category', 'Ranged Weapon' );

    $mock_char->set_always( 'get_equipped_item', $mock_weapon );
    $mock_char->set_always( 'effect_value',      0 );

    is( RPG::Schema::Character::number_of_attacks($mock_char), 1, '1 attacks allowed this for an archer', );

    is( RPG::Schema::Character::number_of_attacks( $mock_char, (2) ), 1, '1 attacks allowed this for an archer', );

    is( RPG::Schema::Character::number_of_attacks( $mock_char, (1) ), 2, '2 attacks allowed this for an archer', );
}

sub test_execute_defence_basic : Tests(1) {
    my $self = shift;

    # GIVEN
    my $char = $self->{schema}->resultset('Character')->create( {} );

    my $item1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Armour',
    );

    # WHEN
    my $result = $char->execute_defence;

    # THEN
    is( $result, undef, "Does nothing if armour has no durability" );
}

sub test_execute_defence_decrement_durability : Tests(2) {
    my $self = shift;

    # GIVEN
    my $char = $self->{schema}->resultset('Character')->create( {} );

    my $item1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Armour',
        variables           => [
            {
                item_variable_name  => 'Durability',
                item_variable_value => 5,
            },
        ],
    );

    # Force decrement
    $self->{roll_result} = 1;

    # WHEN
    my $result = $char->execute_defence;

    # THEN
    is( $result, undef, "No message returned" );
    $item1->discard_changes;
    is( $item1->variable('Durability'), 4, "Durability decremented" );
}

sub test_execute_defence_armour_broken : Tests(2) {
    my $self = shift;

    # GIVEN
    my $char = $self->{schema}->resultset('Character')->create( {} );

    my $item1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Armour',
        variables           => [
            {
                item_variable_name  => 'Durability',
                item_variable_value => 1,
            },
        ],
    );

    # Force decrement
    $self->{roll_result} = 1;

    # WHEN
    my $result = $char->execute_defence;

    # THEN
    is_deeply( $result, { armour_broken => 1 }, "Message returned to indicate broken armour" );
    $item1->discard_changes;
    is( $item1->variable('Durability'), 0, "Durability now 0" );
}

sub test_attack_factor_melee_weapon : Tests(1) {
    my $self = shift;

    # GIVEN
    my $char = $self->{schema}->resultset('Character')->create( { strength => 5, } );

    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Weapon',
        category_name       => 'Melee Weapon',
        attributes          => [
            {
                item_attribute_name  => 'Attack Factor',
                item_attribute_value => 3,
            },
            {
                item_attribute_name  => 'Back Rank Penalty',
                item_attribute_value => 3,
            }
        ],
    );

    # WHEN
    my $af = $char->attack_factor;

    # THEN
    is( $af, 8, "Attack factor set correctly" );

}

sub test_attack_factor_ranged_weapon_with_upgrade : Tests(1) {
    my $self = shift;

    # GIVEN
    my $char = $self->{schema}->resultset('Character')->create( { strength => 5, agility => 3 } );

    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Weapon',
        category_name       => 'Ranged Weapon',
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
    my $af = $char->attack_factor;

    # THEN
    is( $af, 8, "Attack factor set correctly" );

}

sub test_attack_factor_melee_weapon_from_back_rank : Tests(1) {
    my $self = shift;

    # GIVEN
    my $char = $self->{schema}->resultset('Character')->create( { strength => 5, } );
    my $mock_char = Test::MockObject::Extends->new($char);
    $mock_char->set_false('in_front_rank');

    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $mock_char->id,
        super_category_name => 'Weapon',
        category_name       => 'Melee Weapon',
        attributes          => [
            {
                item_attribute_name  => 'Attack Factor',
                item_attribute_value => 3,
            },
            {
                item_attribute_name  => 'Back Rank Penalty',
                item_attribute_value => 2,
            }
        ],
    );

    # WHEN
    my $af = $mock_char->attack_factor;

    # THEN
    is( $af, 6, "Attack factor set correctly" );

}

sub test_ammunition_for_item : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $char = Test::RPG::Builder::Character->build_character($self->{schema});
    
    my $ammo1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Ammo',
        category_name       => 'Ammo',
        variables => [
            {
                item_variable_name => 'Quantity',
                item_variable_value => 5,
            
            },
        ]
    );
    
    my $ammo2 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Ammo',
        category_name       => 'Ammo',
        variables => [
            {
                item_variable_name => 'Quantity',
                item_variable_value => 20,
            },
        ],        
    );
    
    $ammo2->update({item_type_id => $ammo1->item_type_id});
    
    my $weapon = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Weapon',
        category_name       => 'Ranged Weapon',
        attributes          => [
            {
                item_attribute_name  => 'Ammunition',
                item_attribute_value => $ammo1->item_type_id,
            },
        ],
    );
    
    # WHEN
    my $ammo = $char->ammunition_for_item($weapon);
    
    # THEN
    my $expected = [
        {   
            id => $ammo1->id,
            quantity => 5,
        },
        {
            id => $ammo2->id,
            quantity => 20,            
        }
    ];
    
    is_deeply($ammo, $expected, "Expected result returned");
}

1;
