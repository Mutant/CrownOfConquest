package RPG::Schema::Party_Town;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/InflateColumn::DateTime Numeric Core/);
__PACKAGE__->table('Party_Town');

__PACKAGE__->add_columns(qw/party_id town_id tax_amount_paid_today raids_today prestige guards_killed/);

__PACKAGE__->add_columns(
	last_raid_start => { data_type => 'datetime' },
	last_raid_end   => { data_type => 'datetime' },
);

__PACKAGE__->belongs_to( 'party', 'RPG::Schema::Party', { 'foreign.party_id' => 'self.party_id' } );

__PACKAGE__->set_primary_key(qw/party_id town_id/);

__PACKAGE__->numeric_columns(
	prestige => {
		min_value => -100,
		max_value => 100,
	},
	'raids_today',
	'guards_killed',
);

1;
