package RPG::Combat::CreatureWildernessBattle;

use Moose;

with qw/
    RPG::Combat::Battle
    RPG::Combat::CreatureBattle 
    RPG::Combat::InWilderness
/;

1;