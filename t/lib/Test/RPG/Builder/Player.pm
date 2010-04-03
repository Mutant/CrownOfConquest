use strict;
use warnings;

package Test::RPG::Builder::Player;

sub build_player {
	my $self = shift;
	my $schema = shift;
	my %params = @_;
	
    my $player = $schema->resultset('Player')->create( 
        { 
            player_name => 'name', 
            email => 'foo@bar.com', 
            password => 'pass', 
            verified => 1,
            warned_for_deletion => 1,
            deleted => 1, 
            display_tip_of_the_day => $params{tip_of_the_day} || 1,
        } 
    );
    
    return $player;
}

1;