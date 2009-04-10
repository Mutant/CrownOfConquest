use strict;
use warnings;

package Test::RPG::Builder::Party;

sub build_party {
    my $package = shift;
    my $schema = shift;
    my %params = @_;

    my $location = $schema->resultset('Land')->create( {} );
    
    my $player_id;
    
    if (! $params{player_id}) {
        my $player = $schema->resultset('Player')->create( 
            {
                player_name => int rand 100000000,        
            }
        );
        
        $params{player_id} = $player->id;
    };
    
    my $party = $schema->resultset('Party')->create( 
        {
            land_id => $location->id,
            player_id => $params{player_id},        
        } 
    );
    
    return $party;
}

1;
