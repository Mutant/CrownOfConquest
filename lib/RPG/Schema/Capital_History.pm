package RPG::Schema::Capital_History;
use base 'DBIx::Class';
use strict;
use warnings;

use RPG::DateTime;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Capital_History');

__PACKAGE__->add_columns(qw/capital_id kingdom_id town_id start_date end_date/);

__PACKAGE__->set_primary_key(qw/capital_id/);

__PACKAGE__->belongs_to( 'start_day', 'RPG::Schema::Day', { 'foreign.day_id' => 'self.start_date' } );
__PACKAGE__->belongs_to( 'end_day', 'RPG::Schema::Day', { 'foreign.day_id' => 'self.end_date' } );
__PACKAGE__->belongs_to( 'town', 'RPG::Schema::Town', 'town_id' );

1;