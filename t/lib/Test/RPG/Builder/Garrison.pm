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

    return $garrison;
}

1;
