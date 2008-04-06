use strict;
use warnings;

package RPG::Schema::Equip_Places;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Equip_Places');

__PACKAGE__->add_columns(qw/equip_place_id equip_place_name display_order item_category_id/);

__PACKAGE__->set_primary_key('equip_place_id');


1;