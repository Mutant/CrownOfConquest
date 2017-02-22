use strict;
use warnings;

package RPG::Schema::Grave;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Grave');

__PACKAGE__->add_columns(qw/grave_id character_name epitaph day_created land_id/);

__PACKAGE__->set_primary_key('grave_id');

1;
