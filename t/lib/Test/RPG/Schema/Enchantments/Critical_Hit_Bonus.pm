use strict;
use warnings;

package Test::RPG::Schema::Enchantments::Critical_Hit_Bonus;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Item;
use Test::RPG::Builder::Character;
use Test::RPG::Builder::Item_Type;

sub test_startup : Tests(startup => 1) {
    my $self = shift;

    use_ok('RPG::Schema::Enchantments::Critical_Hit_Bonus');
}

sub test_setup : Tests(setup) {
    my $self = shift;

    $self->{item_type} = Test::RPG::Builder::Item_Type->build_item_type(
        $self->{schema},
        enchantments => ['critical_hit_bonus'],
    );

}

sub test_init : Tests(3) {
    my $self = shift;

    # GIVEN

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
    my @enchantments = $item->item_enchantments;
    is( scalar @enchantments, 1, "One enchantment on item" );
    cmp_ok( $item->variable('Critical Hit Bonus'), '<=', 5, "Bonus within max" );
    cmp_ok( $item->variable('Critical Hit Bonus'), '>=', 1, "Bonus within min" );

}

sub test_bonus_applied : Tests() {
    my $self = shift;

    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, divinity => 10 );
    my $item = $self->{schema}->resultset('Items')->create_enchanted(
        {
            item_type_id => $self->{item_type}->id,
            character_id => $character->id,
        },
        {
            number_of_enchantments => 1,
        },
    );
    $item->variable_row( 'Critical Hit Bonus', 2 );

    $self->{config}{character_divinity_points_per_chance_of_critical_hit} = 10;
    $self->{config}{character_level_per_bonus_point_to_critical_hit}      = 1;

    # WHEN
    my $chance = $character->critical_hit_chance;

    # THEN
    is( $chance, 4, "Critical hit bonus applied" );
}

1;
