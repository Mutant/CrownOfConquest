use strict;
use warnings;

package Test::RPG::Schema::ResourceConsumer;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Item_Type;
use Test::RPG::Builder::Item;

use Data::Dumper;

sub test_consume_items_not_enough : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $building_type = $self->{schema}->resultset('Building_Type')->find(
        {
            name => 'Tower',
        }
    );
    
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 2);
    
    my %items_to_consume = (
        'Wood' => 10,
    );
    
    # WHEN
    my $result = $building_type->consume_items([$party], %items_to_consume);
    
    # THEN
    is($result, 0, "Not enough items to consume");
}

sub test_consume_items_single_type : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $building_type = $self->{schema}->resultset('Building_Type')->find(
        {
            name => 'Tower',
        }
    );
   
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 2);
    my @characters = $party->characters;
    
    my $item_type1 = Test::RPG::Builder::Item_Type->build_item_type($self->{schema}, category_name => 'Resource', item_type => 'Wood',

    );
    
    my $item1 = Test::RPG::Builder::Item->build_item($self->{schema},  
        character_id => $characters[0]->id, item_type_id => $item_type1->id,
        variables => [
            {
                item_variable_name => 'Quantity',
                item_variable_value => 100,
            }
        ],
        no_equip_place => 1,
        
    );        
    
    my %items_to_consume = (
        'Wood' => 10,
    );
    
    # WHEN
    my $result = $building_type->consume_items([$party], %items_to_consume);
    
    # THEN
    is($result, 1, "Consumed successfully");
    
    $item1->discard_changes;
    is($item1->variable('Quantity'), 90, "Consumed item decreased quantity");
}