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
use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Kingdom;

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

sub test_tax_cost_with_negotiation : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 1, character_level => 3);
    my ($char) = $party->characters;
    
    my $skill = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Negotiation',
        }
    ); 
    
    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id => $skill->id,
            character_id => $char->id,
            level => 5,
        }
    );    
    
    my $town = Test::RPG::Builder::Town->build_town($self->{schema}, prosperity => 50);
    
    $self->{config}{tax_per_prosperity} = 0.3;
    $self->{config}{tax_level_modifier} = 0.25;
    $self->{config}{tax_turn_divisor} = 10;
    
    # WHEN
    my $tax_cost = $town->tax_cost($party);
    
    # THEN
    is($tax_cost->{gold}, 37, "Gold cost set correctly");
    is($tax_cost->{turns}, 4, "Turn cost set correctly");       
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

sub test_get_sewer : Tests(2) {
 	my $self = shift;
	
	# GIVEN
	my $town = Test::RPG::Builder::Town->build_town($self->{schema});
	my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema}, type => 'sewer', land_id => $town->land_id);
	
	# WHEN
	my $sewer = $town->sewer;
	
	# THEN
	isa_ok($sewer, 'RPG::Schema::Dungeon', "Sewer");
	is($sewer->type, 'sewer', "Correct type");
}

sub test_coaches_basic : Tests(13) {
  	my $self = shift;
	
	# GIVEN
	my @land = Test::RPG::Builder::Land->build_land($self->{schema}, x_size => 6, 'y_size' => 6);
	my $town1 = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $land[0]->id);
	my $town2 = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $land[24]->id);
	my $town3 = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $land[15]->id);
	my $town4 = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $land[35]->id);
	
	my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 1, character_level => 5);
	
	$self->{config}{town_coach_range} = 4;
	$self->{config}{town_coach_gold_cost} = 100;
	$self->{config}{town_coach_party_level_gold_cost} = 10;
	$self->{config}{town_coach_turn_cost} = 2;
	
	# WHEN
	my @coaches = $town1->coaches($party);
	
	# THEN
	is(scalar @coaches, 2, "2 coaches found");
	
	is($coaches[0]->{town}->town_id, $town2->id, "Correct first town");
	is($coaches[0]->{distance}, 4, "Correct first town distance");
	is($coaches[0]->{gold_cost}, 450, "Correct first town gold cost");
	is($coaches[0]->{turn_cost}, 8, "Correct first town turn cost");
	is($coaches[0]->{tax}{gold}, 65, "Correct first town tax cost");
	is($coaches[0]->{can_enter}, 1, "Correct first town can enter");
	
	is($coaches[1]->{town}->town_id, $town3->id, "Correct second town");
	is($coaches[1]->{distance}, 3, "Correct second town distance");
	is($coaches[1]->{gold_cost}, 350, "Correct second town gold cost");
	is($coaches[1]->{turn_cost}, 6, "Correct second town turn cost");
	is($coaches[1]->{tax}{gold}, 65, "Correct second town tax cost");
	is($coaches[1]->{can_enter}, 1, "Correct second town can enter");
}

sub test_coaches_town_cant_be_entered : Tests(8) {
  	my $self = shift;
	
	# GIVEN
	my @land = Test::RPG::Builder::Land->build_land($self->{schema}, x_size => 6, 'y_size' => 6);
	my $town1 = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $land[0]->id);
	my $town2 = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $land[15]->id);
	
	my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 1, character_level => 5);
	
	$self->{config}{town_coach_range} = 4;
	$self->{config}{town_coach_gold_cost} = 100;
	$self->{config}{town_coach_party_level_gold_cost} = 10;
	$self->{config}{town_coach_turn_cost} = 2;
	
	my $party_town = $self->{schema}->resultset('Party_Town')->find_or_create(
		{
			party_id => $party->id,
			town_id  => $town2->id,
		},
	);
	$party_town->prestige(-90);
	$party_town->update;
	
	# WHEN
	my @coaches = $town1->coaches($party);
	
	# THEN
	is(scalar @coaches, 1, "1 coach found");
	
	is($coaches[0]->{town}->town_id, $town2->id, "Correct town");
	is($coaches[0]->{distance}, 3, "Correct town distance");
	is($coaches[0]->{gold_cost}, 350, "Correct town gold cost");
	is($coaches[0]->{turn_cost}, 6, "Correct town turn cost");
	is($coaches[0]->{tax}{gold}, 85, "Correct town tax cost");
	is($coaches[0]->{can_enter}, 0, "Correct town can enter value");
	is($coaches[0]->{reason}, "You've are not allowed into Test Town. You'll need to wait until your prestige improves before they'll let you in", 
	   "Correct town denial reason");
}

sub test_coaches_specific_town : Tests(8) {
  	my $self = shift;
	
	# GIVEN
	my @land = Test::RPG::Builder::Land->build_land($self->{schema}, x_size => 6, 'y_size' => 6);
	my $town1 = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $land[0]->id);
	my $town2 = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $land[24]->id);
	my $town3 = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $land[15]->id);
	my $town4 = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $land[35]->id);
	
	my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 1, character_level => 5);
	
	$self->{config}{town_coach_range} = 4;
	$self->{config}{town_coach_gold_cost} = 100;
	$self->{config}{town_coach_party_level_gold_cost} = 10;
	$self->{config}{town_coach_turn_cost} = 2;
	
	# WHEN
	my @coaches = $town1->coaches($party, $town2->id);
	
	# THEN
	is(scalar @coaches, 1, "1 coach found");
	
	is($coaches[0]->{town}->town_id, $town2->id, "Correct first town");
	is($coaches[0]->{distance}, 4, "Correct first town distance");
	is($coaches[0]->{gold_cost}, 450, "Correct first town gold cost");
	is($coaches[0]->{turn_cost}, 8, "Correct first town turn cost");
	is($coaches[0]->{tax}{gold}, 65, "Correct first town tax cost");
	is($coaches[0]->{can_enter}, 1, "Correct first town can enter");
}

sub test_change_allegiance : Tests(5) {
    my $self = shift;
    
    # GIVEN
    my $old_kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema}, );
    my $new_kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema}, );
    my $town = Test::RPG::Builder::Town->build_town($self->{schema}, kingdom_id => $old_kingdom->id);
    
    # WHEN
    $town->change_allegiance($new_kingdom);
    
    # THEN
    $town->discard_changes;
    is($town->location->kingdom_id, $new_kingdom->id, "Town now loyal to new kingdom");
    
    my @messages1 = $new_kingdom->messages;
    is(scalar @messages1, 1, "1 message added to new kingdom");
    is($messages1[0]->message, "The town of Test Town is now loyal to our kingdom.", "correct message text"); 

    my @messages2 = $old_kingdom->messages;
    is(scalar @messages2, 1, "1 message added to old kingdom");
    is($messages2[0]->message, "The town of Test Town is no longer loyal to our kingdom.", "correct message text");
}

sub test_change_allegiance_capital : Tests(6) {
    my $self = shift;
    
    # GIVEN
    my $old_kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema}, );
    my $new_kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema}, );
    my $town = Test::RPG::Builder::Town->build_town($self->{schema}, kingdom_id => $old_kingdom->id);
    $old_kingdom->capital($town->id);
    $old_kingdom->update;
    
    # WHEN
    $town->change_allegiance($new_kingdom);
    
    # THEN
    $town->discard_changes;
    is($town->location->kingdom_id, $new_kingdom->id, "Town now loyal to new kingdom");
    
    my @messages1 = $new_kingdom->messages;
    is(scalar @messages1, 1, "1 message added to new kingdom");
    is($messages1[0]->message, "The town of Test Town is now loyal to our kingdom.", "correct message text"); 

    my @messages2 = $old_kingdom->messages;
    is(scalar @messages2, 1, "1 message added to old kingdom");
    is($messages2[0]->message, "The town of Test Town is no longer loyal to our kingdom. We no longer have a capital!", "correct message text");
    
    $old_kingdom->discard_changes;
    is($old_kingdom->capital, undef, "Old kingdom no longer has a capital");
}

1;
