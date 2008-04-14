use strict;
use warnings;

package RPG::Schema::CreatureType;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Creature_Type');

__PACKAGE__->add_columns(qw/creature_type_id creature_type level weapon/);

__PACKAGE__->set_primary_key('creature_type_id');

1;