use strict;
use warnings;

package Test::RPG::Schema::Items;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;
use Test::Exception;

sub startup : Tests(startup=>1) {
    use_ok('RPG::Schema::Items');
}

sub setup_data : Tests(setup) {
    my $self = shift;

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
    ok( $val1->item_variable_value >= 1 && $val1->item_variable_value <= 10, "Var1 in correct range" );
    is( $val1->max_value, undef, "Max value not set for var1" );

    my $val2 = $self->{item}->variable_row('Var2');
    warn $val2->item_variable_value;
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

1;
