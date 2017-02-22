use strict;
use warnings;

package Test::RPG::Schema::Enchantments::Resistances;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Item;
use Test::RPG::Builder::Character;
use Test::RPG::Builder::Item_Type;

sub test_startup : Tests(startup => 1) {
    my $self = shift;

    use_ok('RPG::Schema::Enchantments::Resistances');
}

sub test_setup : Tests(setup) {
    my $self = shift;

    $self->{item_type} = Test::RPG::Builder::Item_Type->build_item_type(
        $self->{schema},
        enchantments => ['resistances'],
    );
}

sub test_init : Tests(3) {
    my $self = shift;

    # GIVEN
    $self->mock_dice;
    $self->{roll_result} = 15;

    # WHEN
    my $item = $self->{schema}->resultset('Items')->create_enchanted(
        {
            item_type_id => $self->{item_type}->id,
        },
        {
            number_of_enchantments => 1,
        },
    );

    # THEN
    cmp_ok( $item->variable('Resistance Bonus'), '>=', 1, "Resistance bonus >= 1" );
    cmp_ok( $item->variable('Resistance Bonus'), '<=', 20, "Resistance bonus <= 20" );

    is( grep( { $_ eq $item->variable('Resistance Type') } qw/fire ice poison/ ), 1, "Resistance type in allowed set" );

    $self->unmock_dice;
}

sub test_init_resist_all : Tests(3) {
    my $self = shift;

    # GIVEN
    $self->mock_dice;
    $self->{roll_result} = 5;

    # WHEN
    my $item = $self->{schema}->resultset('Items')->create_enchanted(
        {
            item_type_id => $self->{item_type}->id,
        },
        {
            number_of_enchantments => 1,
        },
    );

    # THEN
    cmp_ok( $item->variable('Resistance Bonus'), '>=', 1, "Resistance bonus >= 1" );
    cmp_ok( $item->variable('Resistance Bonus'), '<=', 10, "Resistance bonus <= 10" );

    is( $item->variable('Resistance Type'), 'all', "Resistance type is all" );

    $self->unmock_dice;
}

sub test_equipping : Tests(2) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, constitution => 20 );

    my $item = $self->{schema}->resultset('Items')->create_enchanted(
        {
            item_type_id => $self->{item_type}->id,
        },
        {
            number_of_enchantments => 1,
        },
    );
    $item->variable( 'Resistance Bonus', 3 );
    $item->variable( 'Resistance Type',  'ice' );
    $item->update;

    # WHEN
    $item->character_id( $character->id );
    $item->equip_place_id(1);
    $item->update;

    # THEN
    $character->discard_changes;
    is( $character->resist_ice_bonus, 3, "Resist ice bonus increased" );
    is( $character->resistance('Ice'), 3, "Resistance to ice calculated correctly" );

}

sub test_equipping_all_resistances : Tests(6) {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, constitution => 20 );

    my $item = $self->{schema}->resultset('Items')->create_enchanted(
        {
            item_type_id => $self->{item_type}->id,
        },
        {
            number_of_enchantments => 1,
        },
    );
    $item->variable( 'Resistance Bonus', 3 );
    $item->variable( 'Resistance Type',  'all' );
    $item->update;

    # WHEN
    $item->character_id( $character->id );
    $item->equip_place_id(1);
    $item->update;

    # THEN
    $character->discard_changes;
    is( $character->resist_ice_bonus, 3, "Resist ice bonus increased" );
    is( $character->resistance('Ice'), 3, "Resistance to ice calculated correctly" );
    is( $character->resist_fire_bonus, 3, "Resist fire bonus increased" );
    is( $character->resistance('Fire'), 3, "Resistance to fire calculated correctly" );
    is( $character->resist_poison_bonus, 3, "Resist poison bonus increased" );
    is( $character->resistance('Poison'), 3, "Resistance to poison calculated correctly" );
}

1;
