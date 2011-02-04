package RPG::Schema::Special_Rooms::Interface;
# Interface for special room roles

use Moose::Role;

# Defined by the role
requires qw/generate/;

1;