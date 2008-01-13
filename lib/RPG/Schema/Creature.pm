use strict;
use warnings;

package RPG::Schema::Creature;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Creature');

__PACKAGE__->add_columns(qw/creature_id creature_group_id creature_type_id hit_points_current hit_points_max/);

__PACKAGE__->belongs_to(
    'type',
    'RPG::Schema::CreatureType',
    { 'foreign.creature_type_id' => 'self.creature_type_id' },
);

1;