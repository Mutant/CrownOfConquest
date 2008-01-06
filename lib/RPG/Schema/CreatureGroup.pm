use strict;
use warnings;

package RPG::Schema::CreatureGroup;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Creature_Group');

__PACKAGE__->add_columns(qw/creature_group_id land_id trait_id/);

__PACKAGE__->belongs_to(
    'location',
    'RPG::Schema::Land',
    { 'foreign.land_id' => 'self.land_id' }
);

1;