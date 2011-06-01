package RPG::Schema::Role::Item_Type::Potion_of_Strength;

use strict;
use warnings;

use Moose::Role;

with 'RPG::Schema::Role::Item_Type::Stat_Potion';

sub stat { 'strength' }

1;
