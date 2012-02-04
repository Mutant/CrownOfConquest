use strict;
use warnings;

package Test::RPG::NewDay::Building_Upgrades;

use base qw(Test::RPG::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use Test::RPG::Builder::Party;

use RPG::NewDay::Action::Building_Upgrades;

use Test::More;

use Test::RPG::Builder::Building;
use Test::RPG::Builder::Land;
use Test::RPG::Builder::Garrison;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Kingdom;
use Test::RPG::Builder::Town;

sub setup : Test(setup) {
    my $self = shift;

    $self->setup_context;  
    
    $self->{action} = RPG::NewDay::Action::Building_Upgrades->new( context => $self->{mock_context} );
    
    $self->mock_dice;
}

sub test_process_market_party_owner : Tests(3) {
    my $self = shift;
    
    # GIVEN
    my $building = Test::RPG::Builder::Building->build_building($self->{schema});
    my $party = $building->owner;
    my $upgrade_type = $self->{schema}->resultset('Building_Upgrade_Type')->find(
        {
            name => 'Market',
        }
    );
    $building->add_to_upgrades(
        {
            type_id => $upgrade_type->type_id,
            level => 2,
        }
    );
    
    $self->{roll_result} = 10;
    
    # WHEN
    $self->{action}->process_market($building->upgrades);
    
    # THEN
    $party->discard_changes;
    is($party->gold, 120, "Party gold increased");
    
    my @messages = $party->messages;
    is(scalar @messages, 1, "One message created");
    like($messages[0]->message, qr{20 gold}, "Gold collected correct in message");
}

sub test_process_market_garrison_owner : Tests(3) {
    my $self = shift;
    
    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, land_id => $land[4]->id, );
	my $building = Test::RPG::Builder::Building->build_building( $self->{schema}, owner_id => $party->id, owner_type => 'party', land_id => $land[4]->id, );

    my $upgrade_type = $self->{schema}->resultset('Building_Upgrade_Type')->find(
        {
            name => 'Market',
        }
    );
    $building->add_to_upgrades(
        {
            type_id => $upgrade_type->type_id,
            level => 2,
        }
    );
    
    $self->{roll_result} = 10;
    
    # WHEN
    $self->{action}->process_market($building->upgrades);
    
    # THEN
    $garrison->discard_changes;
    is($garrison->gold, 20, "Garrison gold increased");
    
    my @messages = $garrison->messages;
    is(scalar @messages, 1, "One message created");
    like($messages[0]->message, qr{20 gold}, "Gold collected correct in message");
}

sub test_process_market_kingdom_owner : Tests(3) {
    my $self = shift;
    
    # GIVEN
	my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
	my $building = Test::RPG::Builder::Building->build_building( $self->{schema}, owner_id => $kingdom->id, owner_type => 'kingdom' );

    my $upgrade_type = $self->{schema}->resultset('Building_Upgrade_Type')->find(
        {
            name => 'Market',
        }
    );
    $building->add_to_upgrades(
        {
            type_id => $upgrade_type->type_id,
            level => 2,
        }
    );
    
    $self->{roll_result} = 10;
    
    # WHEN
    $self->{action}->process_market($building->upgrades);
    
    # THEN
    $kingdom->discard_changes;
    is($kingdom->gold, 120, "Kingdom gold increased");
    
    my @messages = $kingdom->messages;
    is(scalar @messages, 1, "One message created");
    like($messages[0]->message, qr{20 gold}, "Gold collected correct in message");
}

sub test_process_market_town_owner : Tests(3) {
    my $self = shift;
    
    # GIVEN
	my $town = Test::RPG::Builder::Town->build_town($self->{schema});
	my $building = Test::RPG::Builder::Building->build_building( $self->{schema}, owner_id => $town->id, owner_type => 'town' );

    my $upgrade_type = $self->{schema}->resultset('Building_Upgrade_Type')->find(
        {
            name => 'Market',
        }
    );
    $building->add_to_upgrades(
        {
            type_id => $upgrade_type->type_id,
            level => 2,
        }
    );
    
    $self->{roll_result} = 10;
    
    # WHEN
    $self->{action}->process_market($building->upgrades);
    
    # THEN
    $town->discard_changes;
    is($town->gold, 20, "Town gold increased");
    
    my @messages = $town->history;
    is(scalar @messages, 2, "Two messages created");
    like($messages[0]->message, qr{20 gold}, "Gold collected correct in message");
}


1;