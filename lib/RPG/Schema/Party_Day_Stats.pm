package RPG::Schema::Party_Day_Stats;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Party_Day_Stats');

__PACKAGE__->add_columns(qw/date party_id turns_used/);

__PACKAGE__->set_primary_key(qw/date party_id/);

1;