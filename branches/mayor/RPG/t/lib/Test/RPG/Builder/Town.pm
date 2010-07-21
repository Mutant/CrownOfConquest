use strict;
use warnings;

package Test::RPG::Builder::Town;

sub build_town {
    my $package = shift;
    my $schema = shift;
    my %params = @_;
    
    unless ($params{land_id}) {
        my $location = $schema->resultset('Land')->create( {} );
        $params{land_id} = $location->id;
    }
    
    my $town = $schema->resultset('Town')->create(
        {
            land_id => $params{land_id},
            prosperity => $params{prosperity} || 50,
            blacksmith_age => $params{blacksmith_age} || 0,
        }   
    );
    
    return $town;
}

1;