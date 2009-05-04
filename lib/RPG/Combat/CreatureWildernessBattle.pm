package RPG::Combat::CreatureWildernessBattle;

use Moose;

with qw/
    RPG::Combat::Battle
    RPG::Combat::CreatureBattle 
    RPG::Combat::InWilderness
/;

after 'finish' => sub {
    my $self = shift;
    
    $self->location->creature_threat( $self->location->creature_threat - 5 );
    $self->location->update;
};    

1;