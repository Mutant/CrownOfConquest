package RPG::Combat::CreatureDungeonBattle;

use Moose;

with qw/
    RPG::Combat::Battle
    RPG::Combat::CreatureBattle 
    RPG::Combat::InDungeon
/;

__PACKAGE__->meta->make_immutable;

1;