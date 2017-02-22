use strict;
use warnings;

package Test::RPG::C::Building;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Item_Type;
use Test::RPG::Builder::Item;

use Data::Dumper;

use RPG::C::Building;

sub test_get_party_resources : Tests(2) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my @characters = $party->characters;

    my $item_type1 = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema}, category_name => 'Resource', item_type => 'Iron' );
    my $item_type2 = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema}, category_name => 'Resource', item_type => 'Wood' );

    my $item1 = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $characters[0]->id, item_type_id => $item_type1->id,
        variables => [ { item_variable_name => 'Quantity', item_variable_value => 100, } ], no_equip_place => 1 );
    my $item2 = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $characters[0]->id, item_type_id => $item_type2->id,
        variables => [ { item_variable_name => 'Quantity', item_variable_value => 100, } ], no_equip_place => 1 );
    my $item3 = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $characters[1]->id, item_type_id => $item_type1->id,
        variables => [ { item_variable_name => 'Quantity', item_variable_value => 100, } ], no_equip_place => 1 );
    my $item4 = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $characters[0]->id,, no_equip_place => 1 );

    $self->{stash}{party} = $party;

    # WHEN
    my %resources = RPG::C::Building->get_party_resources( $self->{c} );

    # THEN
    is( $resources{Iron}, 200, "Correct resource count for iron" );
    is( $resources{Wood}, 100, "Correct resource count for iron" );
}

1;
