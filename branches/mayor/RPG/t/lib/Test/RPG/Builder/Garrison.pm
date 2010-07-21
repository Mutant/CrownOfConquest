use strict;
use warnings;

package Test::RPG::Builder::Garrison;

use Test::RPG::Builder::Character;

use DateTime;

sub build_garrison {
    my $package = shift;
    my $schema  = shift;
    my %params  = @_;
    
    unless ($params{land_id}) {
        my $location = $schema->resultset('Land')->create( {x=>1, y=>1} );
        $params{land_id} = $location->id;
    }    

    my $garrison = $schema->resultset('Garrison')->create(
        {
            land_id => $params{land_id},
            party_id => $params{party_id},
			
        }
    );
    
    if ( $params{character_count} ) {
        for ( 1 .. $params{character_count} ) {
            Test::RPG::Builder::Character->build_character(
                $schema,
                party_id   => $params{party_id},
                garrison_id => $garrison->id,
                level      => $params{character_level} || 1,
            );
        }
    }    

    return $garrison;
}

1;
