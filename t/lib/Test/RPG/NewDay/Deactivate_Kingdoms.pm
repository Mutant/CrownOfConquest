use strict;
use warnings;

package Test::RPG::NewDay::Deactivate_Kingdoms;

use base qw(Test::RPG::NewDay::ActionBase);
__PACKAGE__->runtests unless caller();

use Test::More;

use Test::RPG::Builder::Kingdom;
use Test::RPG::Builder::Land;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Town;

sub setup : Test(setup => 1) {
    my $self = shift;

    use_ok 'RPG::NewDay::Action::Deactivate_Kingdoms';

    $self->setup_context;
}

sub test_check_for_inactive_still_active : Tests(2) {
    my $self = shift;

    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema}, 'x_size' => 5, 'y_size' => 5 );
    foreach my $land (@land) {
        $land->kingdom_id( $kingdom->id );
        $land->update;
    }
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $land[0]->id );

    my $action = RPG::NewDay::Action::Deactivate_Kingdoms->new( context => $self->{mock_context} );

    # WHEN
    my $result = $action->check_for_inactive($kingdom);

    # THEN
    is( $result, 0, "Kingdom not inactive" );

    $kingdom->discard_changes;
    is( $kingdom->active, 1, "Kingdom still active" );

}

sub test_check_for_inactive_marked_inactive : Tests(14) {
    my $self = shift;

    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema}, 'x_size' => 3, 'y_size' => 3 );
    foreach my $land (@land) {
        $land->kingdom_id( $kingdom->id );
        $land->update;
    }
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, kingdom_id => $kingdom->id, character_count => 2 );
    my $character = $kingdom->king;

    my $town = Test::RPG::Builder::Town->build_town( $self->{schema},
        kingdom_loyalty => {
            $kingdom->id => 30,
          }
    );

    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, kingdom_id => $kingdom->id, character_count => 2 );

    my $action = RPG::NewDay::Action::Deactivate_Kingdoms->new( context => $self->{mock_context} );

    # WHEN
    my $result = $action->check_for_inactive($kingdom);

    # THEN
    is( $result, 1, "Kingdom is now inactive" );

    $kingdom->discard_changes;
    is( $kingdom->active, 0, "Kingdom marked inactive" );

    foreach my $land (@land) {
        $land->discard_changes;
        is( $land->kingdom_id, undef, "Sector " . $land->x . ", " . $land->y . " made neutral" );
    }

    $character->discard_changes;
    is( $character->status, undef, "Character is no longer king" );

    $party2->discard_changes;
    is( $party2->kingdom_id, undef, "Party 2 no longer loyal to kingdom" );

    my $kingdom_town = $self->{schema}->resultset('Kingdom_Town')->find(
        {
            kingdom_id => $kingdom->id,
            town_id    => $town->id,
        }
    );
    is( $kingdom_town, undef, "Kingdom_Town records deleted" );
}

sub test_check_for_inactive_buildings_change_ownership : Tests(22) {
    my $self = shift;

    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema}, 'x_size' => 3, 'y_size' => 3 );

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, kingdom_id => $kingdom->id, character_count => 2 );
    my $character = $kingdom->king;
    $character->party_id( $party->id );
    $character->update;

    my $building = Test::RPG::Builder::Building->build_building( $self->{schema}, owner_id => $kingdom->id, owner_type => 'kingdom', land_id => $land[1]->id );
    $building->claim_land;

    my $action = RPG::NewDay::Action::Deactivate_Kingdoms->new( context => $self->{mock_context} );

    # WHEN
    my $result = $action->check_for_inactive($kingdom);

    # THEN
    is( $result, 1, "Kingdom is now inactive" );

    $kingdom->discard_changes;
    is( $kingdom->active, 0, "Kingdom marked inactive" );

    foreach my $land (@land) {
        $land->discard_changes;
        is( $land->kingdom_id, undef, "Sector " . $land->x . ", " . $land->y . " made neutral" );
        is( $land->claimed_by_id, undef, "Sector not claimed by anything" );
    }

    $building->discard_changes;
    is( $building->owner_id,   $party->id, "Building has correct owner id" );
    is( $building->owner_type, 'party',    "Building has correct owner type" );

}

1;
