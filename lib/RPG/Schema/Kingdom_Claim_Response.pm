package RPG::Schema::Kingdom_Claim_Response;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Kingdom_Claim_Response');

__PACKAGE__->add_columns(qw/claim_id party_id response/);

__PACKAGE__->set_primary_key(qw/claim_id party_id/);

1;
