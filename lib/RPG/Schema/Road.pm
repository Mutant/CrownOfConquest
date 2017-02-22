package RPG::Schema::Road;
use base 'DBIx::Class';
use strict;
use warnings;

use Carp;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Road');

__PACKAGE__->resultset_class('RPG::ResultSet::Road');

__PACKAGE__->add_columns(qw/road_id land_id position/);

__PACKAGE__->set_primary_key('road_id');

__PACKAGE__->belongs_to( 'location', 'RPG::Schema::Land', { 'foreign.land_id' => 'self.land_id' } );

1;
