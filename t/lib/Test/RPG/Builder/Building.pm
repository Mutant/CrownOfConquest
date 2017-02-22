use strict;
use warnings;

package Test::RPG::Builder::Building;

use Test::RPG::Builder::Party;

sub build_building {
    my $package = shift;
    my $schema  = shift;
    my %params  = @_;

    if ( !$params{building_type_id} ) {
        my $type = $schema->resultset('Building_Type')->find(
            {
                building_type_id => 1,
            }
        );
        $params{building_type_id} = $type->id;
    }

    unless ( $params{land_id} ) {
        my $location = $schema->resultset('Land')->create( {} );
        $params{land_id} = $location->id;
    }

    unless ( $params{owner_id} ) {
        my $party = Test::RPG::Builder::Party->build_party($schema);
        $params{owner_id}   = $party->id;
        $params{owner_type} = 'party';
    }

    my $building = $schema->resultset('Building')->create(
        {
            building_type_id => $params{building_type_id},
            land_id          => $params{land_id},
            owner_id         => $params{owner_id},
            owner_type       => $params{owner_type}
        }
    );

    if ( $params{upgrades} ) {
        foreach my $upgrade_type ( keys %{ $params{upgrades} } ) {
            my $type = $schema->resultset('Building_Upgrade_Type')->find(
                {
                    name => $upgrade_type,
                }
            );

            die "No such upgrade type: $upgrade_type" unless $type;

            $building->add_to_upgrades(
                {
                    type_id => $type->id,
                    level   => $params{upgrades}->{$upgrade_type},
                }
            );
        }
    }

    return $building;

}

1;
