use strict;
use warnings;

package Test::RPG::Builder::Dungeon;

sub build_dungeon {
    my $package = shift;
    my $schema = shift;
    my %params = @_;
    
    unless ($params{land_id}) {
        my $location = $schema->resultset('Land')->create( {} );
        $params{land_id} = $location->id;
    }
    
    my $dungeon = $schema->resultset('Dungeon')->create(
        {
            land_id => $params{land_id},
            level => $params{level} || 1,
            type => $params{type} || 'dungeon',            
        }   
    );
    
    return $dungeon;    	
}

1;
