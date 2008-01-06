package RPG::Schema;

use strict;
use warnings;

use base qw/DBIx::Class::Schema/;

__PACKAGE__->load_classes(qw/
    Items Item_Category Race Item_Type Player Party Terrain Land Dimension Class Character Shop Items_In_Shop
    Creature CreatureType CreatureGroup Trait
/);

1;
