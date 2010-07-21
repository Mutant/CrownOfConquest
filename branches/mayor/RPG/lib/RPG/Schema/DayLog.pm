use strict;
use warnings;

package RPG::Schema::DayLog;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Day_Log');

__PACKAGE__->add_columns(qw/day_log_id day_id log party_id displayed/);

__PACKAGE__->set_primary_key('day_log_id');

__PACKAGE__->belongs_to(
    'day',
    'RPG::Schema::Day',
    { 'foreign.day_id' => 'self.day_id' }
);


1;