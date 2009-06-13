use strict;
use warnings;

package Test::RPG::Schema::Town;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Town;

use RPG::Schema::Town;

sub test_tax_cost_basic : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 3, character_level => 3);
    my $town = Test::RPG::Builder::Town->build_town($self->{schema}, prosperty => 50);
    
    $self->{config}{tax_per_prosperity} = 0.5;
    $self->{config}{tax_level_modifier} = 0.5;
    $self->{config}{tax_turn_divisor} = 10;
    
    # WHEN
    my $tax_cost = $town->tax_cost($party);
    
    # THEN
    is($tax_cost->{gold}, 50, "Gold cost set correctly");
    is($tax_cost->{turns}, 5, "Turn cost set correctly");       
}

sub test_tax_cost_with_prestige : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 1, character_level => 10);
    my $town = Test::RPG::Builder::Town->build_town($self->{schema}, prosperity => 50);
    
    my $party_town = $self->{schema}->resultset('Party_Town')->create(
        {
            party_id => $party->id,
            town_id => $town->id,
            prestige => 20,   
        }
    );
    
    $self->{config}{tax_per_prosperity} = 0.3;
    $self->{config}{tax_level_modifier} = 0.7;
    $self->{config}{tax_turn_divisor} = 10;
    
    # WHEN
    my $tax_cost = $town->tax_cost($party);
    
    # THEN
    is($tax_cost->{gold}, 90, "Gold cost set correctly");
    is($tax_cost->{turns}, 9, "Turn cost set correctly");       
}

1;