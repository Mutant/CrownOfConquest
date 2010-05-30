package RPG::Schema::Enchantments::Interface;
# Interface for enchantment roles

use Moose::Role;

# Defined by the role
requires qw/init_enchantment is_usable must_be_equipped label target/;

# For good measure, we also list things required to be in the schema class
requires qw/add_to_variables item/;

1;