use strict;
use warnings;

package Test::RPG::Schema::Quest::Construct_Building;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::RPG::Builder::Land;
use Test::RPG::Builder::Kingdom;
use Test::RPG::Builder::Building;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::Quest;

use Test::More;

sub test_set_quest_params : Tests(3) {
    my $self = shift;
 
    # GIVEN   
    my $schema = $self->{schema};
    
    my @land = Test::RPG::Builder::Land->build_land($schema, x_size => 10, 'y_size' => 10);
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom($schema);
    
    my $building1 = Test::RPG::Builder::Building->build_building($schema);
    my $building2 = Test::RPG::Builder::Building->build_building($schema);
    my $building3 = Test::RPG::Builder::Building->build_building($schema);
    my $building4 = Test::RPG::Builder::Building->build_building($schema);    
    my $town1 = Test::RPG::Builder::Town->build_town($schema);
    my $town2 = Test::RPG::Builder::Town->build_town($schema);
    
    # Setup the kingdom, buildings and towns.. should constrain us to 1 available sector
    foreach my $land (@land) {
        if ($land->x >= 6 and $land->y >= 6) {
            $land->kingdom_id($kingdom->id);
            $land->update;
        }
        
        if ($land->x == 5 and $land->y == 6) {
            $building1->land_id($land->id);
            $building1->update;
        }
        
        if ($land->x == 7 and $land->y == 9) {
            $building2->land_id($land->id);
            $building2->update;
        }
        
        if ($land->x == 10 and $land->y == 4) {
            $building3->land_id($land->id);
            $building3->update;
        }
        
        if ($land->x == 4 and $land->y == 9) {
            $building4->land_id($land->id);
            $building4->update;
        }        
        
        if ($land->x == 8 and $land->y == 6) {
            $town1->land_id($land->id);
            $town1->update;
        }

        if ($land->x == 10 and $land->y == 8) {
            $town2->land_id($land->id);
            $town2->update;
        }
    }
    
   
    my $quest_type = $schema->resultset('Quest_Type')->find( { 'quest_type' => 'construct_building' } );
    
    $self->{config}{quest_type_vars} = {
        construct_building => {
            building_search_range => 3,
            town_search_range => 3,
            search_range => 3,
        },
    };    
    
    # WHEN
    my $quest = $schema->resultset('Quest')->create(
        {
            kingdom_id    => $kingdom->id,
            quest_type_id => $quest_type->id,
        }
    );
    
    # THEN
    isa_ok($quest, 'RPG::Schema::Quest::Construct_Building', "Quest created in correct package");
    my $sector = $quest->sector_to_build_in;
    is($sector->x, 10, "Correct x location for build location");
    is($sector->y, 6, "Correct y location for build location");    
}

sub test_check_action_constructed_building : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
    my $party = Test::RPG::Builder::Party->build_party($self->{schema});
    my $building = Test::RPG::Builder::Building->build_building($self->{schema}, land_id => $party->location->land_id);   
        
    my $quest = Test::RPG::Builder::Quest->build_quest($self->{schema}, 
        quest_type => 'construct_building', 
        kingdom_id => $kingdom->id, 
        party_id => $party->id,
        params => {
            'Building Type' => $building->building_type_id,
            'Building Location' => $party->location->land_id,
        },
    );
        
    # WHEN
    my $res = $quest->check_action($party, 'constructed_building', $building);
    
    # THEN
    is($res, 1, "Action was successful");
    
    is($quest->param('Built'), 1, "Quest param updated");
 
}

sub test_check_action_ceded_building : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, kingdom_id => $kingdom->id);
    
    my $building_type = $self->{schema}->resultset('Building_Type')->find(
        {
            name => 'Tower',
        }
    );    
    my $building = Test::RPG::Builder::Building->build_building($self->{schema}, 
        land_id => $party->location->land_id,
        building_type_id => $building_type->id,
        owner_type => 'kingdom',
        owner_id => $kingdom->id,
    );   
        
    my $quest = Test::RPG::Builder::Quest->build_quest($self->{schema}, 
        quest_type => 'construct_building', 
        kingdom_id => $kingdom->id, 
        party_id => $party->id,
        params => {
            'Building Type' => $building->building_type_id,
            'Building Location' => $party->location->land_id,
        },
    );
        
    # WHEN
    my $res = $quest->check_action($party, 'ceded_building', $building);
    
    # THEN
    is($res, 1, "Action was successful");
    
    $quest->discard_changes;
    is($quest->status, 'Awaiting Reward', "Quest's status updated");
 
}

sub test_check_action_ceded_building_castle : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, kingdom_id => $kingdom->id);
    
    my $building_type = $self->{schema}->resultset('Building_Type')->find(
        {
            name => 'Castle',
        }
    );    
    
    my $tower_building_type = $self->{schema}->resultset('Building_Type')->find(
        {
            name => 'Tower',
        }
    );        
    
    my $building = Test::RPG::Builder::Building->build_building($self->{schema}, 
        land_id => $party->location->land_id,
        building_type_id => $building_type->id,
        owner_type => 'kingdom',
        owner_id => $kingdom->id,
    );   
        
    my $quest = Test::RPG::Builder::Quest->build_quest($self->{schema}, 
        quest_type => 'construct_building', 
        kingdom_id => $kingdom->id, 
        party_id => $party->id,
        params => {
            'Building Type' => $tower_building_type->id,
            'Building Location' => $party->location->land_id,
        },
    );
        
    # WHEN
    my $res = $quest->check_action($party, 'ceded_building', $building);
    
    # THEN
    is($res, 1, "Action was successful");
    
    $quest->discard_changes;
    is($quest->status, 'Awaiting Reward', "Quest's status updated");
 
}

1;