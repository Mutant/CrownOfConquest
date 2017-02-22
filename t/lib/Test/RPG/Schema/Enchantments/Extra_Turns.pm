use strict;
use warnings;

package Test::RPG::Schema::Enchantments::Extra_Turns;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Item;
use Test::RPG::Builder::Character;
use Test::RPG::Builder::Item_Type;
use Test::RPG::Builder::Party;

sub test_startup : Tests(startup => 1) {
    my $self = shift;

    use_ok('RPG::Schema::Enchantments::Extra_Turns');
}

sub test_setup : Tests(setup) {
    my $self = shift;

    $self->{item_type} = Test::RPG::Builder::Item_Type->build_item_type(
        $self->{schema},
        enchantments => ['extra_turns'],
    );

}

sub test_new_day_adds_turns : Tests(1) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, turns => 100 );
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id );
    my $item = $self->{schema}->resultset('Items')->create_enchanted(
        {
            item_type_id => $self->{item_type}->id,
            character_id => $character->id,
        },
        {
            number_of_enchantments => 1,
        },
    );
    $item->variable_row( 'Extra Turns',      20 );
    $item->variable_row( 'Must Be Equipped', 0 );

    my $mock_context = Test::MockObject->new();
    $mock_context->set_always( 'config',      $self->{config} );
    $mock_context->set_always( 'id',          1000 );
    $mock_context->set_always( 'current_day', $mock_context );

    my ($enchantment) = $item->item_enchantments;

    # WHEN
    $enchantment->new_day($mock_context);

    # THEN
    $party->discard_changes;
    is( $party->turns, 120, "Turns have been increased" );
}

sub test_new_day_adds_turns_doesnt_exceed_max : Tests(1) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, turns => 100 );
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id );
    my $item1 = $self->{schema}->resultset('Items')->create_enchanted(
        {
            item_type_id => $self->{item_type}->id,
            character_id => $character->id,
        },
        {
            number_of_enchantments => 1,
        },
    );
    $item1->variable_row( 'Extra Turns',      20 );
    $item1->variable_row( 'Must Be Equipped', 0 );

    my $item2 = $self->{schema}->resultset('Items')->create_enchanted(
        {
            item_type_id => $self->{item_type}->id,
            character_id => $character->id,
        },
        {
            number_of_enchantments => 1,
        },
    );
    $item2->variable_row( 'Extra Turns',      250 );
    $item2->variable_row( 'Must Be Equipped', 0 );

    my $mock_context = Test::MockObject->new();
    $mock_context->set_always( 'config',      $self->{config} );
    $mock_context->set_always( 'id',          1000 );
    $mock_context->set_always( 'current_day', $mock_context );

    my ($enchantment1) = $item1->item_enchantments;
    my ($enchantment2) = $item2->item_enchantments;

    # WHEN
    $enchantment1->new_day($mock_context);
    $enchantment2->new_day($mock_context);

    # THEN
    $party->discard_changes;
    is( $party->turns, 350, "Turns have been increased, but not above the maximum" );
}

1;
