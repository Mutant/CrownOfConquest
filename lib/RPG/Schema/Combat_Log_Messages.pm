package RPG::Schema::Combat_Log_Messages;
use base 'DBIx::Class';
use strict;
use warnings;

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Combat_Log_Messages');

__PACKAGE__->add_columns(
    qw/log_message_id round message combat_log_id opponent_number/
);

__PACKAGE__->set_primary_key('log_message_id');

__PACKAGE__->belongs_to( 'combat_log', 'RPG::Schema::Combat_Log', 'combat_log_id' );

1;
