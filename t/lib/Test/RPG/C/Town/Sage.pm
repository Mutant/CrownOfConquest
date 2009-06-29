use strict;
use warnings;

package Test::RPG::C::Town::Sage;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Data::Dumper;

use Test::MockObject;
use Test::More;
use Test::Exception;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Town;

use RPG::C::Town::Sage;

sub test_calculate_costs_has_discount : Tests(5) {
    my $self = shift;   
    
    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town($self->{schema});
    $town->discount_type('sage');
    $town->discount_threshold(10);
    $town->discount_value(30);
    $town->update;
    
    my $party = Test::RPG::Builder::Party->build_party($self->{schema});
    
    my $party_town = $self->{schema}->resultset('Party_Town')->find_or_create(
        {
            party_id => $party->id,
            town_id  => $town->id,
            prestige => 10,
        },
    );    
    
    $self->{config}{sage_direction_cost} = 100;
    $self->{config}{sage_distance_cost} = 100;
    $self->{config}{sage_location_cost} = 200;
    $self->{config}{sage_item_find_cost} = 50;
    $self->{config}{sage_find_dungeon_cost_per_level} = 150;
    
    $self->{stash}{party} = $party;
    
    # WHEN
    my $costs = RPG::C::Town::Sage->calculate_costs($self->{c}, $town);
    
    # THEN
    is($costs->{direction_cost}, 70, "Direction cost set correctly");
    is($costs->{distance_cost}, 70, "Distance cost set correctly");
    is($costs->{location_cost}, 140, "Location cost set correctly");
    is($costs->{item_find_cost}, 35, "Item Find cost set correctly");
    is($costs->{find_dungeon_cost_per_level}, 105, "Dungeon find cost set correctly");
    
    
}

1;