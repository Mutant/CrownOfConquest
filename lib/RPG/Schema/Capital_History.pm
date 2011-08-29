package RPG::Schema::Capital_History;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Capital_History');

__PACKAGE__->add_columns(qw/capital_id kingdom_id town_id start_date end_date/);

__PACKAGE__->set_primary_key(qw/capital_id/);

1;