use strict;
use warnings;

package RPG::Schema::Garrison_Messages;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Garrison_Messages');

__PACKAGE__->add_columns(qw/garrison_message_id day_id garrison_id message/);

__PACKAGE__->set_primary_key('garrison_message_id');

__PACKAGE__->belongs_to(
    'day',
    'RPG::Schema::Day',
    { 'foreign.day_id' => 'self.day_id' }
);

1;
