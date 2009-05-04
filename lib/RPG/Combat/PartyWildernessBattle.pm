package RPG::Combat::PartyWildernessBattle;

use Moose;

with qw/
    RPG::Combat::Battle
    RPG::Combat::PartyBattle 
    RPG::Combat::InWilderness
/;

1;