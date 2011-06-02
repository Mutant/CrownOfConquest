use strict;
use warnings;

package RPG::Schema::Trade;

use base 'DBIx::Class';

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Trade');

__PACKAGE__->add_columns(qw/trade_id town_id party_id item_id offered_to status amount/);

__PACKAGE__->set_primary_key(qw/trade_id/);

__PACKAGE__->belongs_to( 'item', 'RPG::Schema::Items', 'item_id' );
__PACKAGE__->belongs_to( 'party', 'RPG::Schema::Party', 'party_id' );


1;