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

sub test_become_mayor : Tests(2) {
	my $self = shift;
	
	# GIVEN
	my $town = Test::RPG::Builder::Town->build_town($self->{schema});
	$town->mayor_rating(10);
	$town->peasant_state('revolt');
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
	$self->{stash}{today} = Test::RPG::Builder::Day->build_day($self->{schema});
	
	$self->{mock_forward}{'/panel/refresh'} = sub {};
	
	# WHEN
	RPG::C::Town->become_mayor($self->{c});	
	
	# THEN
	$character->discard_changes;
	is($character->mayor_of, $town->id, "Character now mayor of town");
	
	
	$party_town->discard_changes;
	is($party_town->prestige, 0, "Prestige reset");	
	
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
