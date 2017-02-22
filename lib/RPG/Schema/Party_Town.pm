package RPG::Schema::Party_Town;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/Numeric Core/);
__PACKAGE__->table('Party_Town');

__PACKAGE__->add_columns(qw/party_id town_id tax_amount_paid_today prestige/);

__PACKAGE__->belongs_to( 'party', 'RPG::Schema::Party', { 'foreign.party_id' => 'self.party_id' } );

__PACKAGE__->set_primary_key(qw/party_id town_id/);

__PACKAGE__->numeric_columns(
    prestige => {
        min_value => -100,
        max_value => 100,
    },
);

1;
