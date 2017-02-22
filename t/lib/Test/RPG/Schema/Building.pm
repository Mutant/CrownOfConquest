use strict;
use warnings;

package Test::RPG::Schema::Building;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Building;
use Test::RPG::Builder::Land;
use Test::RPG::Builder::Kingdom;
use Test::RPG::Builder::Town;

sub test_get_bonus : Tests(1) {
    my $self = shift;

    # GIVEN
    $self->{schema}->resultset('Building_Upgrade_Type')->search()->update( { modifier_per_level => 3 } );

    my $building = Test::RPG::Builder::Building->build_building( $self->{schema} );
    my $upgrade_type = $self->{schema}->resultset('Building_Upgrade_Type')->find(
        {
            name => 'Rune of Defence',
        }
    );
    $building->add_to_upgrades(
        {
            type_id => $upgrade_type->type_id,
            level   => 2,
        }
    );

    # WHEN
    my $bonus = $building->get_bonus('defence_factor');

    # THEN
    is( $bonus, 10, "DF bonus correct" );
}

sub test_claim_land : Tests(27) {
    my $self = shift;

    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema}, );
    my $building = Test::RPG::Builder::Building->build_building( $self->{schema}, owner_type => 'kingdom', owner_id => $kingdom->id, land_id => $land[4]->id );

    # WHEN
    $building->claim_land;

    # THEN
    foreach my $land (@land) {
        $land->discard_changes;
        is( $land->kingdom_id, $kingdom->id, "Land now claimed by kingdom" );
        is( $land->claimed_by_id, $building->id, "Building claimed sector " . $land->id );
        is( $land->claimed_by_type, 'building', "Claimed by type correct for sector " . $land->id );
    }
}

sub test_claim_land_doesnt_override_another_claim : Tests(36) {
    my $self = shift;

    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema}, x_size => 3, 'y_size' => 4, );
    my $kingdom1 = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema}, );
    my $kingdom2 = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema}, );
    my $building = Test::RPG::Builder::Building->build_building( $self->{schema}, owner_type => 'kingdom', owner_id => $kingdom1->id, land_id => $land[4]->id );

    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, land_id => $land[6]->id, );
    $land[6]->kingdom_id( $kingdom2->id );
    $land[6]->update;
    $town->claim_land;

    # WHEN
    $building->claim_land;

    # THEN
    foreach my $land (@land) {
        $land->discard_changes;

        if ( $land->y == 1 ) {
            is( $land->kingdom_id, $kingdom1->id, "Land now claimed by kingdom 1" );
            is( $land->claimed_by_id, $building->id, "Building claimed sector " . $land->x . ',' . $land->y );
            is( $land->claimed_by_type, 'building', "Claimed by type correct for sector " . $land->x . ',' . $land->y );
        }
        else {
            is( $land->kingdom_id, $kingdom2->id, "Land still claimed by kingdom 2" );
            is( $land->claimed_by_id, $town->id, "Town claimed sector " . $land->x . ',' . $land->y );
            is( $land->claimed_by_type, 'town', "Claimed by type correct for sector " . $land->x . ',' . $land->y );
        }
    }
}

1;
