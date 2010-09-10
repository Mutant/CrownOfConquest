use strict;
use warnings;

package Test::RPG::Schema::Town;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::Land;
use Test::RPG::Builder::Day;

use RPG::Schema::Town;

sub test_tax_cost_basic : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 3, character_level => 3);
    my $town = Test::RPG::Builder::Town->build_town($self->{schema}, prosperty => 50);
    
    $self->{config}{tax_per_prosperity} = 0.3;
    $self->{config}{tax_level_modifier} = 0.25;
    $self->{config}{tax_turn_divisor} = 10;
    
    # WHEN
    my $tax_cost = $town->tax_cost($party);
    
    # THEN
    is($tax_cost->{gold}, 40, "Gold cost set correctly");
    is($tax_cost->{turns}, 4, "Turn cost set correctly");       
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
    $self->{config}{tax_level_modifier} = 0.25;
    $self->{config}{tax_turn_divisor} = 10;
    
    # WHEN
    my $tax_cost = $town->tax_cost($party);
    
    # THEN
    is($tax_cost->{gold}, 119, "Gold cost set correctly");
    is($tax_cost->{turns}, 12, "Turn cost set correctly");       
}

sub test_has_road_to_connected : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land($self->{schema}, x_size => 5, 'y_size' => 5);
    
    my $town1 = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $land[0]->id);
    my $town2 = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $land[19]->id);
    
    $land[1]->add_to_roads(
        {
            position => 'top',
        },
    );
    
    $land[1]->add_to_roads(
        {
            position => 'bottom right',
        },
    );    
   
    $land[7]->add_to_roads(
        {
            position => 'top left',
        },
    );     
    
    $land[7]->add_to_roads(
        {
            position => 'bottom right',
        },
    );      
   
    $land[13]->add_to_roads(
        {
            position => 'top left',
        },
    );     
    
    $land[13]->add_to_roads(
        {
            position => 'bottom right',
        },
    );
    
    # WHEN
    my $result = $town1->has_road_to($town2);
    
    # THEN
    is($result, 1, "Towns are connected by roads");
      
}

sub test_has_road_to_not_connected : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land($self->{schema}, x_size => 5, 'y_size' => 5);
    
    my $town1 = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $land[0]->id);
    my $town2 = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $land[19]->id);
    
    $land[1]->add_to_roads(
        {
            position => 'top',
        },
    );
    
    $land[1]->add_to_roads(
        {
            position => 'bottom right',
        },
    );    
   
    $land[7]->add_to_roads(
        {
            position => 'top left',
        },
    );     
    
    $land[7]->add_to_roads(
        {
            position => 'bottom right',
        },
    );      
   
    $land[13]->add_to_roads(
        {
            position => 'top left',
        },
    );     
    
    # WHEN
    my $result = $town1->has_road_to($town2);
    
    # THEN
    is($result, 0, "Towns are not connected by roads");
}

sub test_take_sales_tax : Tests(5) {
	my $self = shift;
	
	# GIVEN
	my $town = Test::RPG::Builder::Town->build_town($self->{schema});
	$town->sales_tax(20);
	$town->update;
	
	# WHEN
	$town->take_sales_tax(100);
	
	# THEN
	is($town->gold, 20, "Correct amount of gold added to town coffers");
	my @logs = $town->history;
	is(scalar @logs, 1, "One history line added");
	is($logs[0]->type, 'income', "History line correct type");
	is($logs[0]->value, 20, "History line correct value");
	is($logs[0]->day_id, $self->{stash}{today}->id, "Correct day used for history");
		
}


1;