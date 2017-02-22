package RPG::Schema::Party_Messages_Recipients;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Party_Messages_Recipients');

__PACKAGE__->add_columns(qw/message_id party_id has_read/);

__PACKAGE__->set_primary_key(qw/message_id party_id/);

__PACKAGE__->belongs_to(
    'party',
    'RPG::Schema::Party',
    'party_id',
);

1;
