use strict;
use warnings;

package Test::RPG::Schema::Building_Type;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Item;
use Test::RPG::Builder::Item_Type;

sub test_cost_to_build : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $building_type = $self->{schema}->resultset('Building_Type')->find(
        {
            name => 'Tower',
        }
    );
    
    # WHEN
    my %costs = $building_type->cost_to_build;
    
    # THEN
    my %expected = (
        Clay => 16,
        Stone => 6,
        Wood => 15,
        Iron => 8,
    );
    is_deeply(\%costs, \%expected, "Cost to build returned correctly");
    
}

sub test_cost_to_build_with_skilled_party : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 2);
    my @chars = $party->characters;
    my $skill = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Construction',
        }
    );
    
    my $char_skill1 = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id => $skill->id,
            character_id => $chars[0]->id,
            level => 10,
        }
    );
    
    my $char_skill2 = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id => $skill->id,
            character_id => $chars[1]->id,
            level => 5,
        }
    );    
    
    my $building_type = $self->{schema}->resultset('Building_Type')->find(
        {
            name => 'Tower',
        }
    );
    
    # WHEN
    my %costs = $building_type->cost_to_build([$party]);
    
    # THEN
    my %expected = (
        Clay => 11,
        Stone => 4,
        Wood => 10,
        Iron => 5,
    );
    is_deeply(\%costs, \%expected, "Cost to build returned correctly");
    
}


sub test_consume_items : Tests() {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 2);
    my @characters = $party->characters;
    
    my $item_type1 = Test::RPG::Builder::Item_Type->build_item_type($self->{schema}, category_name => 'Resource', item_type => 'Type1',

    );
    
    my $building_type = $self->{schema}->resultset('Building_Type')->find(
        {
            name => 'Tower',
        }
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
    
    my $item2 = Test::RPG::Builder::Item->build_item($self->{schema},  
        character_id => $characters[0]->id, item_type_id => $item_type1->id,
        variables => [
            {
                item_variable_name => 'Quantity',
                item_variable_value => 100,
            }
        ],
        no_equip_place => 1,
    );
        
    my $item3 = Test::RPG::Builder::Item->build_item($self->{schema}, category_name => 'Resource',
        variables => [
            {
                item_variable_name => 'Quantity',
                item_variable_value => 200,
            }
        ], character_id => $characters[1]->id, item_type_name => 'Type2', no_equip_place => 1,);
    
    # WHEN
    $building_type->consume_items(
        [$party],
        (
            'Type1' => 150,
            'Type2' => 150,
        )
    );
    
    # THEN
    $item1->discard_changes;
    is($item1->variable('Quantity'), undef, "Item1 used up");

    $item2->discard_changes;
    is($item2->variable('Quantity'), 50, "Item2 used up");

    $item3->discard_changes;
    is($item3->variable('Quantity'), 50, "Item3 used up");
       
}
