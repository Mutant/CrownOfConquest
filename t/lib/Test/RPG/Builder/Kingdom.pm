use strict;
use warnings;

package Test::RPG::Builder::Kingdom;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Land;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::Building;

sub build_kingdom {
    my $package = shift;
    my $schema  = shift;
    my %params  = @_;

    my $kingdom = $schema->resultset('Kingdom')->create(
        {
            name                 => 'Test Kingdom',
            mayor_tax            => $params{mayor_tax} // 10,
            gold                 => $params{gold} // 100,
            active               => $params{active} // 1,
            majesty_leader_since => $params{majesty_leader_since} // undef,
            has_crown            => $params{has_crown} // 0,
            capital              => $params{capital} // undef,
        }
    );

    $params{create_king} //= 1;

    if ( $params{create_king} ) {
        my $character = Test::RPG::Builder::Character->build_character($schema);
        $character->status('king');
        $character->status_context( $kingdom->id );
        $character->update;
    }

    if ( $params{land_count} ) {
        my $land_to_create = $params{land_count} - $params{town_count};
        Test::RPG::Builder::Land->build_land( $schema, x_size => 1, 'y_size' => $land_to_create, kingdom_id => $kingdom->id );
    }

    if ( $params{party_count} ) {
        for ( 1 .. $params{party_count} ) {
            Test::RPG::Builder::Party->build_party( $schema, kingdom_id => $kingdom->id );
        }
    }

    if ( $params{town_count} ) {
        for ( 1 .. $params{town_count} ) {
            Test::RPG::Builder::Town->build_town( $schema, kingdom_id => $kingdom->id );
        }
    }

    if ( $params{building_count} ) {
        for ( 1 .. $params{building_count} ) {
            Test::RPG::Builder::Building->build_building( $schema, owner_id => $kingdom->id, owner_type => 'kingdom' );
        }
    }

    return $kingdom;
}

1;
