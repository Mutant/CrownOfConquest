package RPG::Schema::Kingdom_Messages;
use base 'DBIx::Class';
use strict;
use warnings;


__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Kingdom_Messages');

__PACKAGE__->add_columns(qw/message_id kingdom_id day_id message type party_id/);

__PACKAGE__->set_primary_key('message_id');

__PACKAGE__->belongs_to( 'day', 'RPG::Schema::Day', 'day_id' );
__PACKAGE__->belongs_to( 'party', 'RPG::Schema::Party', 'party_id' );

1;