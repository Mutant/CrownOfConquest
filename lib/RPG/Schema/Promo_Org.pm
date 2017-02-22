package RPG::Schema::Promo_Org;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Promo_Org');

__PACKAGE__->add_columns(qw/promo_org_id name extra_start_turns/);
__PACKAGE__->set_primary_key('promo_org_id');

1;
