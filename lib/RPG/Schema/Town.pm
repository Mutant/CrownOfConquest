use strict;
use warnings;

package RPG::Schema::Town;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Town');

__PACKAGE__->add_columns(qw/town_id town_name land_id prosperity/);

__PACKAGE__->set_primary_key('town_id');

__PACKAGE__->has_many(
    'shops',
    'RPG::Schema::Shop',
    { 'foreign.town_id' => 'self.town_id' },
);

__PACKAGE__->has_many(
    'quests',
    'RPG::Schema::Quest',
    { 'foreign.town_id' => 'self.town_id' }
);

1;