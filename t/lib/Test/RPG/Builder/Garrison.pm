use strict;
use warnings;

package Test::RPG::Builder::Garrison;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Character;

use DateTime;

sub build_garrison {
    my $package = shift;
    my $schema  = shift;
    my %params  = @_;

    unless ( $params{land_id} ) {
        my $location = $schema->resultset('Land')->find_or_create( { x => 1, y => 2 } );
        $params{land_id} = $location->id;
    }

    unless ( $params{party_id} ) {
        my $party = Test::RPG::Builder::Party->build_party($schema);
        $params{party_id} = $party->id;
    }

    my $garrison = $schema->resultset('Garrison')->create(
        {
            land_id  => $params{land_id},
            party_id => $params{party_id},
            party_attack_mode => $params{party_attack_mode} || 'Attack Stronger Opponents',
            established    => $params{established}    // DateTime->now(),
            flee_threshold => $params{flee_threshold} // 70,
        }
    );

    if ( $params{character_count} ) {
        for ( 1 .. $params{character_count} ) {
            Test::RPG::Builder::Character->build_character(
                $schema,
                party_id    => $params{party_id},
                garrison_id => $garrison->id,
                level       => $params{character_level} || 1,
                %params,
            );
        }
    }

    return $garrison;
}

1;
