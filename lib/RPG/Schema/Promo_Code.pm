package RPG::Schema::Promo_Code;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/Numeric Core/);
__PACKAGE__->table('Promo_Code');

__PACKAGE__->add_columns(qw/code_id code promo_org_id uses_remaining/);
__PACKAGE__->set_primary_key('code_id');

__PACKAGE__->numeric_columns(
    uses_remaining => {
        min_value => 0,
      }
);

__PACKAGE__->belongs_to( 'promo_org', 'RPG::Schema::Promo_Org', 'promo_org_id' );

__PACKAGE__->belongs_to( 'player', 'RPG::Schema::Player', { 'foreign.promo_code_id' => 'self.code_id' } );

1;
