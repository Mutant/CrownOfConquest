use strict;
use warnings;

package RPG::Schema::Crown_History;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Crown_History');

__PACKAGE__->add_columns(qw/history_id day_id message/);

__PACKAGE__->set_primary_key('history_id');

__PACKAGE__->belongs_to( 'day', 'RPG::Schema::Day', { 'foreign.day_id' => 'self.day_id' } );

1;
