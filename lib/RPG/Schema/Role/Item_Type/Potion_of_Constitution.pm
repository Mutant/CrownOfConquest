package RPG::Schema::Role::Item_Type::Potion_of_Constitution;

use strict;
use warnings;

use Moose::Role;

with 'RPG::Schema::Role::Item_Type::Stat_Potion';

sub stat { 'constitution' }

1;
