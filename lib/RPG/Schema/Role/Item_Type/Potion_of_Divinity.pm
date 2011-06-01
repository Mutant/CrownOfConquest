package RPG::Schema::Role::Item_Type::Potion_of_Divinity;

use strict;
use warnings;

use Moose::Role;

with 'RPG::Schema::Role::Item_Type::Stat_Potion';

sub stat { 'divinity' }

1;
