package RPG::Schema::Role::Item_Type::Potion;

use strict;
use warnings;

use Moose::Role;

with 'RPG::Schema::Role::Item_Type::Usable';

sub target {
    return 'self';
}

1;