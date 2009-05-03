package RPG::Combat::CreatureDungeonBattle;

use Moose;

with qw/
    RPG::Combat::Battle
    RPG::Combat::CreatureBattle 
    RPG::Combat::InDungeon
/;

1;