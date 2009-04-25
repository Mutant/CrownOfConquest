use strict;
use warnings;

package RPG::Schema::Day;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('`Day`');

__PACKAGE__->resultset_class('RPG::ResultSet::Day');

__PACKAGE__->add_columns(qw/day_id day_number game_year date_started/);

__PACKAGE__->set_primary_key('day_id');

1;