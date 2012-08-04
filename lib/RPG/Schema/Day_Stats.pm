use strict;
use warnings;

package RPG::Schema::Day_Stats;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Day_Stats');

__PACKAGE__->add_columns(qw/date visitors/);

__PACKAGE__->set_primary_key('date');

1;