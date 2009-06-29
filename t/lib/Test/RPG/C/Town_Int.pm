use strict;
use warnings;

package Test::RPG::C::Town_Int;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Data::Dumper;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::Land;
use Test::RPG::Builder::Day;

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
    is($party->gold, 87, "Party gold reduced");
    is( defined $party_town,                1,  "party town record created" );
    is( $party_town->tax_amount_paid_today, 13, "Gold amount recorded" );
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

sub test_raid_party_raid_succeeds : Tests(3) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_level => 1, character_count => 3 );
    my $town  = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50 );
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    $party->land_id($land[0]->id);
    $party->update;
    $town->land_id($land[1]->id);
    $town->update;
    
    my $day = Test::RPG::Builder::Day->build_day($self->{schema});
    
    $self->{config}{minimum_raid_level} = 1;
    
    $party = Test::MockObject::Extends->new($party);
    $party->set_series('average_stat', 30,20,30);
    
    $self->{stash}{party} = $party;
    $self->{stash}{party_location} = $party->location;
    $self->{params}{town_id} = $town->id;
    
    $self->mock_dice;
    $self->{rolls} = [50, 1];
    
    $self->{mock_forward}{'/panel/refresh'} = sub { };
    $self->{mock_forward}{'/quest/check_action'} = sub { };
    
    # WHEN
    RPG::C::Town->raid( $self->{c} );   
    
    # THEN
    $party->discard_changes;
    is($party->gold, 401, "Party gold increased");
    is($party->turns, 87, "Party turns decreased");
    
    my $party_town = $self->{schema}->resultset('Party_Town')->find(
        {
            party_id => $party->id,
            town_id => $town->id,
        },
    );
    is($party_town->raids_today, 1, "Number of raids today recorded");
}

sub test_raid_failure : Tests(4) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_level => 1, character_count => 3 );
    my $town  = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50 );
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    $party->land_id($land[0]->id);
    $party->update;
    $town->land_id($land[1]->id);
    $town->update;
    
    my $day = Test::RPG::Builder::Day->build_day($self->{schema});
    
    $self->{config}{minimum_raid_level} = 1;
    
    $party = Test::MockObject::Extends->new($party);
    $party->set_series('average_stat', 30,20,30);
    
    $self->{stash}{party} = $party;
    $self->{stash}{party_location} = $party->location;
    $self->{params}{town_id} = $town->id;
    
    $self->mock_dice;
    $self->{rolls} = [21, 1];
    
    $self->{mock_forward}{'/panel/refresh'} = sub { };
    
    # WHEN
    RPG::C::Town->raid( $self->{c} );   
    
    # THEN
    $party->discard_changes;
    is($party->gold, 100, "Party gold not increased");
    is($party->turns, 87, "Party turns decreased");
    
    my $party_town = $self->{schema}->resultset('Party_Town')->find(
        {
            party_id => $party->id,
            town_id => $town->id,
        },
    );
    is($party_town->raids_today, 1, "Number of raids today recorded");
    is($party_town->prestige, -8, "Prestige reduced");
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

1;
