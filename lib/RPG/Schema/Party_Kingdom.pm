package RPG::Schema::Party_Kingdom;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/Numeric Core/);
__PACKAGE__->table('Party_Kingdom');

__PACKAGE__->add_columns(qw/party_id kingdom_id loyalty/);

__PACKAGE__->set_primary_key(qw/party_id kingdom_id/);

__PACKAGE__->numeric_columns(
	loyalty => {
		min_value => -100,
		max_value => 100,
	},
);

1;