package Test::RPG::ResultSet::Items;

use strict;
use warnings;

use base qw(Test::RPG::DB);

use Test::More;
use Test::RPG::Builder::Item_Type;

__PACKAGE__->runtests() unless caller();

sub startup : Tests(startup=>1) {
    my $self = shift;

    use_ok 'RPG::ResultSet::Items';
}

sub test_create_enchanted_0_enchantments : Tests(2) {
    my $self = shift;

    # GIVEN
    my $item_type = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema}, enchantments => ['spell_casts_per_day'] );

    # WHEN
    my $item = $self->{schema}->resultset('Items')->create_enchanted(
        {
            item_type_id => $item_type->id,
        },
    );

    # THEN
    isa_ok( $item, 'RPG::Schema::Items', "Item created correctly" );
    my @enchantments = $item->item_enchantments;
    is( scalar @enchantments, 0, "No enchantments on item" );
}

sub test_create_enchanted_1_enchantment : Tests(2) {
    my $self = shift;

    # GIVEN
    my $item_type = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema}, enchantments => ['spell_casts_per_day'] );

    # WHEN
    my $item = $self->{schema}->resultset('Items')->create_enchanted(
        {
            item_type_id => $item_type->id,
        },
        {
            number_of_enchantments => 1,
        }
    );

    # THEN
    isa_ok( $item, 'RPG::Schema::Items', "Item created correctly" );
    my @enchantments = $item->item_enchantments;
    is( scalar @enchantments, 1, "One enchantment on item" );

}

sub test_create_enchanted_non_enchantable_type : Tests(2) {
    my $self = shift;

    # GIVEN
    my $item_type = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema} );

    # WHEN
    my $item = $self->{schema}->resultset('Items')->create_enchanted(
        {
            item_type_id => $item_type->id,
        },
        {
            number_of_enchantments => 1,
        }
    );

    # THEN
    isa_ok( $item, 'RPG::Schema::Items', "Item created correctly" );
    my @enchantments = $item->item_enchantments;
    is( scalar @enchantments, 0, "No enchantments on item" );
}

sub test_create_enchanted_one_per_item : Tests(4) {
    my $self = shift;

    # GIVEN
    my $item_type = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema}, enchantments => [ 'indestructible', 'magical_damage' ] );

    # WHEN
    my $item = $self->{schema}->resultset('Items')->create_enchanted(
        {
            item_type_id => $item_type->id,
        },
        {
            number_of_enchantments => 2,
        }
    );

    # THEN
    isa_ok( $item, 'RPG::Schema::Items', "Item created correctly" );
    my @enchantments = $item->item_enchantments;
    is( scalar @enchantments, 2, "Two enchantments on item" );

    @enchantments = sort { $a->enchantment->enchantment_name cmp $b->enchantment->enchantment_name } @enchantments;
    is( $enchantments[0]->enchantment->enchantment_name, 'indestructible', "First enchantment is indescrutible" );
    is( $enchantments[1]->enchantment->enchantment_name, 'magical_damage', "First enchantment is magical_damage" );

}

sub test_create_enchanted_max_value : Tests(3) {
    my $self = shift;

    # GIVEN
    my $item_type = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema}, enchantments => ['spell_casts_per_day'] );

    # WHEN
    my $item = $self->{schema}->resultset('Items')->create_enchanted(
        {
            item_type_id => $item_type->id,
        },
        {
            number_of_enchantments => 1,
            max_value              => 500,
        }
    );

    # THEN
    isa_ok( $item, 'RPG::Schema::Items', "Item created correctly" );
    my @enchantments = $item->item_enchantments;
    is( scalar @enchantments, 1, "One enchantment on item" );
    cmp_ok( $item->sell_price, '<=', 500, "Item price under max_value" );

}

sub test_create_enchanted_returns_item_even_if_cant_create_under_max_value : Tests(2) {
    my $self = shift;

    # GIVEN
    my $item_type = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema}, enchantments => ['spell_casts_per_day'] );

    # WHEN
    my $item = $self->{schema}->resultset('Items')->create_enchanted(
        {
            item_type_id => $item_type->id,
        },
        {
            number_of_enchantments => 1,
            max_value              => 1,
        }
    );

    # THEN
    isa_ok( $item, 'RPG::Schema::Items', "Item created correctly" );
    my @enchantments = $item->item_enchantments;
    is( scalar @enchantments, 0, "Item is not enchanted" );

}

1;
