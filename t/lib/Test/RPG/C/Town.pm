use strict;
use warnings;

package Test::RPG::C::Town;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Data::Dumper;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::Land;
use Test::RPG::Builder::Day;
use Test::RPG::Builder::Election;
use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Dungeon_Room;
use Test::RPG::Builder::Kingdom;

use Test::More;
use Test::Exception;
use Test::MockObject::Extends;

use RPG::C::Town;

sub test_enter : Tests(4) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    my $town  = Test::RPG::Builder::Town->build_town( $self->{schema} );
    $town->land_id(5555);
    $town->prosperity(50);
    $town->update;

    $self->{stash}{party}           = $party;
    $self->{params}{land_id}        = $town->land_id;
    $self->{params}{payment_method} = 'gold';

    $self->{config} = {
        tax_per_prosperity => 0.5,
        tax_level_modifier => 0.5,
        tax_turn_divisor   => 10,
    };

    $self->{mock_forward}{'/map/move_to'} = sub { };
    $self->{mock_forward}{'/map/can_move_to_sector'} = sub {};

    # WHEN
    RPG::C::Town->enter( $self->{c} );

    # THEN
    my $party_town = $self->{schema}->resultset('Party_Town')->find(
        {
            party_id => $party->id,
            town_id  => $town->id,
        }
    );
    $party->discard_changes;
    is($party->gold, 99, "Party gold reduced");
    is( defined $party_town,                1,  "party town record created" );
    is( $party_town->tax_amount_paid_today, 1, "Gold amount recorded" );
    is( $party_town->prestige, 1, "Prestige increased");

}

sub test_enter_previously_entered : Tests(4) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    my $town  = Test::RPG::Builder::Town->build_town( $self->{schema} );
    $town->land_id(5555);
    $town->prosperity(50);
    $town->update;

    $self->{stash}{party}           = $party;
    $self->{params}{land_id}        = $town->land_id;
    $self->{params}{payment_method} = 'gold';

    $self->{config} = {
        tax_per_prosperity => 0.5,
        tax_level_modifier => 0.5,
        tax_turn_divisor   => 10,
    };

    $self->{mock_forward}{'/map/move_to'} = sub { };
    $self->{mock_forward}{'/map/can_move_to_sector'} = sub {};
    
    my $party_town = $self->{schema}->resultset('Party_Town')->create(
        {
            party_id => $party->id,
            town_id  => $town->id,
            tax_amount_paid_today => 1,
        }
    );    

    # WHEN
    RPG::C::Town->enter( $self->{c} );

    # THEN
    $party->discard_changes;
    is($party->gold, 100, "Party gold unchanged");
    is($party->turns, 100, "Party turns unchanged");
   
    is( $self->{stash}->{entered_town}, 1, "Entered town recorded" );
    
    $party_town->discard_changes;
    is( $party_town->prestige, 0, "Prestige not increased");

}

sub test_raid_party_not_next_to_town : Tests(1) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_level => 1, character_count => 3 );
    my $town  = Test::RPG::Builder::Town->build_town( $self->{schema} );
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    $party->land_id($land[0]->id);
    $party->update;
    $town->land_id($land[8]->id);
    $town->update;
    
    $self->{config}{minimum_raid_level} = 1;
    
    $self->{stash}{party} = $party;
    $self->{stash}{party_location} = $party->location;
    $self->{params}{town_id} = $town->id;
    
    # WHEN / THEN    
    throws_ok(sub { RPG::C::Town->raid( $self->{c} ); }, qr/Not next to that town/, "Dies if raid attempted from town that's not adjacent");   
       
}

sub test_raid_party_ip_address_common_with_mayor : Tests(1) {
    my $self = shift;

    # GIVEN
    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    
    $party1->player->add_to_logins(
        {
            ip => '10.10.10.10',
            login_date => DateTime->now->subtract( days => 3 ),
        }
    );

    $party2->player->add_to_logins(
        {
            ip => '10.10.10.10',
            login_date => DateTime->now->subtract( days => 9 ),
        }
    );
    my $town  = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $party1->land_id );
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    $party1->land_id($land[0]->id);
    $party1->update;
    $town->land_id($land[1]->id);
    $town->update;    
    my $castle = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema}, land_id => $town->land_id, type => 'castle');
    my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, 
        top_left => {x=>1,y=>1}, 
        bottom_right=>{x=>5,y=>5}, 
        dungeon_id => $castle->id,
        make_stairs => 1,
    );

    my ($mayor) = $party2->characters;
    $mayor->update( { mayor_of => $town->id } );
    
    $self->{config}{minimum_raid_level} = 1;
    
    $self->{stash}{party} = $party1;
    $self->{stash}{party_location} = $party1->location;
    $self->{params}{town_id} = $town->id;
    $self->{config}{check_for_coop} = 1;
    
    $self->{mock_forward}{'/panel/refresh'} = sub {};
    
    # WHEN
    RPG::C::Town->raid( $self->{c} );
    
    # THEN
    is($self->{stash}->{error}, "Can't raid this town, as you have IP addresses in common with the mayor's party", "Correct error");
}

sub test_raid_party_ip_address_common_with_previous_mayor : Tests(1) {
    my $self = shift;

    # GIVEN
    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    
    $party1->player->add_to_logins(
        {
            ip => '10.10.10.10',
            login_date => DateTime->now->subtract( days => 3 ),
        }
    );

    $party2->player->add_to_logins(
        {
            ip => '10.10.10.10',
            login_date => DateTime->now->subtract( days => 9 ),
        }
    );
    my $town  = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $party1->land_id );
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    $party1->land_id($land[0]->id);
    $party1->update;
    $town->land_id($land[1]->id);
    $town->update;    
    my $castle = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema}, land_id => $town->land_id, type => 'castle');
    my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, 
        top_left => {x=>1,y=>1}, 
        bottom_right=>{x=>5,y=>5}, 
        dungeon_id => $castle->id,
        make_stairs => 1,
    );
    
    my $old_day = $self->{schema}->resultset('Day')->create(
        {
            day_number => $self->{stash}{today}->day_number -2,
        }
    );
    
    my $pmh = $self->{schema}->resultset('Party_Mayor_History')->create(
        {
            party_id => $party2->id,
            town_id => $town->id,
            got_mayoralty_day => $old_day->id,
            lost_mayoralty_day => $old_day->id,
            character_id => 1,
            mayor_name => 'Mayor',
        }
    );
    
    $self->{config}{minimum_raid_level} = 1;
    
    $self->{stash}{party} = $party1;
    $self->{stash}{party_location} = $party1->location;
    $self->{params}{town_id} = $town->id;
    $self->{config}{check_for_coop} = 1;
    
    $self->{mock_forward}{'/panel/refresh'} = sub {};
    
    # WHEN
    RPG::C::Town->raid( $self->{c} );
    
    # THEN
    is($self->{stash}->{error}, "Can't raid this town, as you have IP addresses in common with a recent mayor's party", "Correct error");
}

sub test_raid_successful : Tests(4) {
    my $self = shift;

    # GIVEN
    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );

    my $town  = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $party1->land_id );
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    $party1->land_id($land[0]->id);
    $party1->update;
    $town->land_id($land[1]->id);
    $town->update;    
    my $castle = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema}, land_id => $town->land_id, type => 'castle');
    my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, 
        top_left => {x=>1,y=>1}, 
        bottom_right=>{x=>5,y=>5}, 
        dungeon_id => $castle->id,
        make_stairs => 1,
    );

    my ($mayor) = $party2->characters;
    $mayor->update( { mayor_of => $town->id } );
    
    $self->{config}{minimum_raid_level} = 1;
    
    $self->{stash}{party} = $party1;
    $self->{stash}{party_location} = $party1->location;
    $self->{params}{town_id} = $town->id;
    
    $self->{mock_forward}{'/panel/refresh'} = sub {};
    
    # WHEN
    RPG::C::Town->raid( $self->{c} );
    
    # THEN
    $party1->discard_changes;
    is(defined $party1->dungeon_grid_id, 1, "Party put into castle");
    
    my @raids = $town->raids;
    is(scalar @raids, 1, "Raid record created");
    is($raids[0]->party_id, $party1->id, "Correct party id on raid record");
    isa_ok($raids[0]->date_started, 'DateTime', "Date of raid started recorded");     
    
}

sub test_raid_successful_but_against_peaceful_kingdom : Tests(7) {
    my $self = shift;

    # GIVEN
    my $kingdom1 = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my $kingdom2 = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );

    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, kingdom_id => $kingdom2->id  );
    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2);
    
    my $town  = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $party1->land_id );
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    
    $party1->land_id($land[0]->id);
    $party1->update;
    
    $town->land_id($land[1]->id);
    $town->update;    
    $land[1]->kingdom_id($kingdom1->id);
    $land[1]->update;
    
	$self->{schema}->resultset('Kingdom_Relationship')->create(
	   {
	       kingdom_id => $kingdom2->id,
	       with_id => $kingdom1->id,
	       type => 'peace',
	   }
	);
    
    my $castle = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema}, land_id => $town->land_id, type => 'castle');
    my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, 
        top_left => {x=>1,y=>1}, 
        bottom_right=>{x=>5,y=>5}, 
        dungeon_id => $castle->id,
        make_stairs => 1,
    );

    my ($mayor) = $party2->characters;
    $mayor->update( { mayor_of => $town->id } );
    
    $self->{config}{minimum_raid_level} = 1;
    
    $self->{stash}{party} = $party1;
    $self->{stash}{party_location} = $party1->location;
    $self->{params}{town_id} = $town->id;
    
    $self->{mock_forward}{'/panel/refresh'} = sub {};
    
    # WHEN
    RPG::C::Town->raid( $self->{c} );
    
    # THEN
    $party1->discard_changes;
    is(defined $party1->dungeon_grid_id, 1, "Party put into castle");
    
    my @raids = $town->raids;
    is(scalar @raids, 1, "Raid record created");
    is($raids[0]->party_id, $party1->id, "Correct party id on raid record");
    isa_ok($raids[0]->date_started, 'DateTime', "Date of raid started recorded");  
	
	is($party1->loyalty_for_kingdom($kingdom2->id), -15, "Party's kingdom loyalty reduced");
	
	is($kingdom2->messages->count, 1, "Message added to kingdom");
	is($kingdom2->messages->first->message, 
	   "The party test raided the town of Test Town, even though the town is loyal to the Kingdom of Test Kingdom, which we are at peace with.", 
	   "Correct message text");
    
}

sub test_calculate_heal_cost_simple : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town($self->{schema});
    
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 2, hit_points => 5);
    
    
    $self->{config}{min_healer_cost} = 1;
    $self->{config}{max_healer_cost} = 6;
    
    $self->{stash}{party} = $party;
    
    # WHEN
    my $cost_to_heal = RPG::C::Town->calculate_heal_cost($self->{c}, $town);
    
    # THEN
    is($cost_to_heal, 40, "Cost to heal returned correctly");
       
}

sub test_calculate_heal_cost_discount_available : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town($self->{schema});
    $town->discount_type('healer');
    $town->discount_threshold(10);
    $town->discount_value(30);
    $town->update;
    
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 2, hit_points => 5);
    
    my $party_town = $self->{schema}->resultset('Party_Town')->find_or_create(
        {
            party_id => $party->id,
            town_id  => $town->id,
            prestige => 10,
        },
    );
    
    $self->{config}{min_healer_cost} = 1;
    $self->{config}{max_healer_cost} = 6;
    
    $self->{stash}{party} = $party;
    
    # WHEN
    my $cost_to_heal = RPG::C::Town->calculate_heal_cost($self->{c}, $town);
    
    # THEN
    is($cost_to_heal, 28, "Cost to heal returned correctly");
       
}

sub test_become_mayor : Tests(7) {
	my $self = shift;
	
	# GIVEN
	my $town = Test::RPG::Builder::Town->build_town($self->{schema});
	$town->mayor_rating(10);
	$town->update;
		
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_level => 1, character_count => 3 );
	my @characters = $party->characters;
	my $character = $characters[0];
	
	my $party_town = $self->{schema}->resultset('Party_Town')->create(
		{
			party_id => $party->id,
			town_id  => $town->id,
			prestige => -10,
		},
	);	

	$self->{params}{character_id} = $character->id;
	$self->{params}{town_id} = $town->id;
	
	$self->{stash}{party} = $party;
	
	$self->{mock_forward}{'/panel/refresh'} = sub {};
	$self->{mock_forward}{'/quest/check_action'} = sub {};
	
	# WHEN
	RPG::C::Town->become_mayor($self->{c});	
	
	# THEN
	$character->discard_changes;
	is($character->mayor_of, $town->id, "Character now mayor of town");	
	
	my $cg = $character->creature_group;
	is(defined $cg, 1, "Mayor added to CG");
	
	$party_town->discard_changes;
	is($party_town->prestige, 0, "Prestige reset");	
	
	my $history_rec = $self->{schema}->resultset('Party_Mayor_History')->find(
        {
            party_id => $party->id,
            town_id => $town->id,
            lost_mayoralty_day => undef,
        }
    );
    is($history_rec->got_mayoralty_day, $self->{stash}{today}->id, "Got mayoralty day recorded");
    is($history_rec->character_id, $character->id, "Character id recorded in history");
    is($history_rec->mayor_name, $character->character_name, "Mayor name recorded in history");
    is($history_rec->creature_group_id, $cg->id, "Creature group recorded in history");
	
}

sub test_become_mayor_but_against_peaceful_kingdom : Tests(10) {
	my $self = shift;
	
	# GIVEN
    my $kingdom1 = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my $kingdom2 = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );	

	$self->{schema}->resultset('Kingdom_Relationship')->create(
	   {
	       kingdom_id => $kingdom2->id,
	       with_id => $kingdom1->id,
	       type => 'peace',
	   }
	);
	
	my $town = Test::RPG::Builder::Town->build_town($self->{schema}, kingdom_id => $kingdom1->id);
	$town->mayor_rating(10);
	$town->update;
		
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_level => 1, character_count => 3, kingdom_id => $kingdom2->id );
	my @characters = $party->characters;
	my $character = $characters[0];
	
	my $party_town = $self->{schema}->resultset('Party_Town')->create(
		{
			party_id => $party->id,
			town_id  => $town->id,
			prestige => -10,
		},
	);	

	$self->{params}{character_id} = $character->id;
	$self->{params}{town_id} = $town->id;
	
	$self->{stash}{party} = $party;
	
	$self->{mock_forward}{'/panel/refresh'} = sub {};
	$self->{mock_forward}{'/quest/check_action'} = sub {};
	
	# WHEN
	RPG::C::Town->become_mayor($self->{c});	
	
	# THEN
	$character->discard_changes;
	is($character->mayor_of, $town->id, "Character now mayor of town");	
	
	my $cg = $character->creature_group;
	is(defined $cg, 1, "Mayor added to CG");
	
	$party_town->discard_changes;
	is($party_town->prestige, 0, "Prestige reset");	
	
	my $history_rec = $self->{schema}->resultset('Party_Mayor_History')->find(
        {
            party_id => $party->id,
            town_id => $town->id,
            lost_mayoralty_day => undef,
        }
    );
    is($history_rec->got_mayoralty_day, $self->{stash}{today}->id, "Got mayoralty day recorded");
    is($history_rec->character_id, $character->id, "Character id recorded in history");
    is($history_rec->mayor_name, $character->character_name, "Mayor name recorded in history");
    is($history_rec->creature_group_id, $cg->id, "Creature group recorded in history");
    
	is($party->loyalty_for_kingdom($kingdom2->id), -20, "Party's kingdom loyalty reduced");
	
	is($kingdom2->messages->count, 1, "Message added to kingdom");
	is($kingdom2->messages->first->message, 
	   "The party test installed a mayor in the town of Test Town, even though the town is loyal to the Kingdom of Test Kingdom, which we are at peace with.", 
	   "Correct message text");    
	
}

sub test_res_from_morgue : Test(3) {
	my $self = shift;
	
	# GIVEN
	my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
	
	my $town = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $land[0]->id);
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_level => 10, character_count => 3, land_id => $land[0]->id, gold => 10000 );
	my @characters = $party->characters;
	my $character = $characters[0];
	
	$character->hit_points(0);
	$character->status('morgue');
	$character->status_context($town->id);
	$character->update;
	
	$self->{params}{character_id} = $character->id;
	
	$self->{stash}{party} = $party;
	$self->{stash}{party_location} = $party->location;	
	
	$self->{mock_forward}{'/town/cemetery'} = sub {};
	$self->{mock_forward}{'res_impl'} = sub { return RPG::C::Town->res_impl($self->{c}, @{ $_[0] }) };
	
	# WHEN
	RPG::C::Town->res_from_morgue($self->{c});
	
	# THEN
	$character->discard_changes;
	is($character->status, undef, "Character returned to party");
	is($character->status_context, undef, "Status context cleared");
	cmp_ok($character->hit_points, '>=', 1, "Character has positive hit points"); 
}

sub test_res_from_morgue_party_full : Test(4) {
	my $self = shift;
	
	# GIVEN
	my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
	
	my $town = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $land[0]->id);
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_level => 10, character_count => 9, land_id => $land[0]->id, gold => 10000 );
	my @characters = $party->characters;
	my $character = $characters[0];
	
	$character->hit_points(0);
	$character->status('morgue');
	$character->status_context($town->id);
	$character->update;
	
	$self->{params}{character_id} = $character->id;
	
	$self->{stash}{party} = $party;
	$self->{stash}{party_location} = $party->location;	
	
	$self->{mock_forward}{'/town/cemetery'} = sub {};
	$self->{mock_forward}{'res_impl'} = sub { return RPG::C::Town->res_impl($self->{c}, @{ $_[0] }) };
	
	# WHEN
	RPG::C::Town->res_from_morgue($self->{c});
	
	# THEN
	$character->discard_changes;
	is($character->status, 'morgue', "Character still in morgue");
	is($character->status_context, $town->id, "Status context unchanged");
	is($character->hit_points, 0, "Character hps unchanged");
	is(defined $self->{stash}{error}, 1, "Error message set"); 
}

1;
