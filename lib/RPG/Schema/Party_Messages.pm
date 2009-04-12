package RPG::Schema::Party_Messages;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Party_Messages');

__PACKAGE__->add_columns(qw/message_id message alert_party day_id party_id/);

__PACKAGE__->set_primary_key('message_id');

__PACKAGE__->belongs_to(
    'day',
    'RPG::Schema::Day',
    { 'foreign.day_id' => 'self.day_id' }
);

1;