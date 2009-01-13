use strict;
use warnings;

package Test::RPG::Builder::Town;

sub build_town {
    my $package = shift;
    my $schema = shift;
    my %params = @_;
    
    my $location = $schema->resultset('Land')->create( {} );
    
    my $town = $schema->resultset('Town')->create(
        {
            land_id => $location->id,            
        }   
    );
    
    return $town;
}

1;