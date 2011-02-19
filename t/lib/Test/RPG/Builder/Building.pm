use strict;
use warnings;

package Test::RPG::Builder::Building;

sub build_building {
	my $package = shift;
	my $schema  = shift;
	my %params = @_;

    if (! $params{building_type_id}) {
        my $type = $schema->resultset('Building_Type')->find(
            {
                building_type_id => 1,
            }
        );
        $params{building_type_id} = $type->id;                 
    }

    unless ($params{land_id}) {
        my $location = $schema->resultset('Land')->create( {} );
        $params{land_id} = $location->id;
    }    

    return $schema->resultset('Building')->create(
        {
            building_type_id => $params{building_type_id},
            land_id => $params{land_id},
            owner_id => $params{owner_id},
            owner_type => $params{owner_type}
        }
    );
	
}

1;