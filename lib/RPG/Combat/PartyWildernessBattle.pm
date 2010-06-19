package RPG::Combat::PartyWildernessBattle;

use Moose;

with qw/
    RPG::Combat::Battle
    RPG::Combat::PartyBattle 
    RPG::Combat::InWilderness
/;

__PACKAGE__->meta->make_immutable;


1;