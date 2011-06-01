package RPG::Schema::Role::Item_Type::Potion_of_Agility;

use strict;
use warnings;

use Moose::Role;

with 'RPG::Schema::Role::Item_Type::Stat_Potion';

sub stat { 'agility' }

1;
