use strict;
use warnings;

package Test::RPG::Schema::Enchantments::Bonus_Against_Creature_Category;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Item;
use Test::RPG::Builder::Character;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Item_Type;
use Test::RPG::Builder::Day;

sub test_startup : Tests(startup => 1) {
    my $self = shift;

    use_ok('RPG::Schema::Enchantments::Bonus_Against_Creature_Category');
}

sub test_init_doesnt_allow_multiple_cats_of_same_type : Tests(21) {
    my $self = shift;

    # GIVEN
    my @cats_created;
    for ( 0 .. 4 ) {
        push @cats_created, $self->{schema}->resultset('Creature_Category')->create( { name => "test_$_" } );
    }
    my @enchantments = ('bonus_against_creature_category') x 5;

    # WHEN
    my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, enchantments => \@enchantments );

    # THEN
    my @item_enchantments = $item->item_enchantments;
    is( scalar @item_enchantments, 5, "5 enchantments on item" );

    my @categories;
    foreach my $enchantment (@item_enchantments) {
        is( $enchantment->enchantment->enchantment_name, 'bonus_against_creature_category', "Enchantment of correct type" );
        cmp_ok( $enchantment->variable('Bonus'), '>=', 1, "Bonus is greater than or equal to 1" );
        cmp_ok( $enchantment->variable('Bonus'), '<=', 10, "Bonus is less than or equal to 10" );
        push @categories, $enchantment->variable('Creature Category');
    }

    my $count = 0;
    foreach my $cat ( sort { $a <=> $b } @categories ) {
        is( $cat, $cats_created[$count]->id, "Correct creature category on enchantment" );
        $count++;
    }
}

1;
