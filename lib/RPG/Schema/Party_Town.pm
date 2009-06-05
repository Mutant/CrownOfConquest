package RPG::Schema::Party_Town;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Party_Town');

__PACKAGE__->add_columns(qw/party_id town_id tax_amount_paid_today raids_today/);

__PACKAGE__->set_primary_key(qw/party_id town_id/);

1;