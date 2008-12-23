use strict;
use warnings;

package Test::RPG::Builder::Party;

sub build_party {
    my $package = shift;
    my $schema = shift;
    my %params = @_;

    my $location = $schema->resultset('Land')->create( {} );
    
    my $player = $schema->resultset('Player')->create( 
        {
            player_name => int rand 100000000,        
        } 
    );
    
    my $party = $schema->resultset('Party')->create( 
        {
            land_id => $location->id,
            player_id => $player->id,        
        } 
    );
    
    return $party;
}

1;
