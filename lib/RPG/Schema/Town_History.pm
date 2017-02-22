package RPG::Schema::Town_History;
use base 'DBIx::Class';
use strict;
use warnings;

use Carp;

__PACKAGE__->load_components(qw/Numeric Core/);
__PACKAGE__->table('Town_History');

__PACKAGE__->resultset_class('RPG::ResultSet::Town_History');

__PACKAGE__->add_columns(qw/town_history_id message town_id day_id date_recorded type value/);

__PACKAGE__->set_primary_key('town_history_id');

__PACKAGE__->belongs_to( 'day', 'RPG::Schema::Day', { 'foreign.day_id' => 'self.day_id' } );

__PACKAGE__->numeric_columns('value');

1;
