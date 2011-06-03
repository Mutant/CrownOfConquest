package RPG::Schema::Town_Guards;
use base 'DBIx::Class';
use strict;
use warnings;

use Carp;

__PACKAGE__->load_components(qw/Numeric Core/);
__PACKAGE__->table('Town_Guards');

__PACKAGE__->add_columns(qw/town_id creature_type_id amount amount_yesterday/);

__PACKAGE__->set_primary_key(qw/town_id creature_type_id/);

__PACKAGE__->numeric_columns(
	amount => {
		min_value => 0,
	},
);

1;